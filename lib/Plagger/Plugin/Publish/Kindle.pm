package Plagger::Plugin::Publish::Kindle;
use strict;
use base qw( Plagger::Plugin );

use Encode;
use Encode::MIME::Header;
use MIME::Lite;

use Digest::MD5 qw(md5_hex);
use File::Spec;
use File::Path;

our %TLSConn;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
	'publish.init' => \&initialize,
        'publish.feed' => \&feed,
        'publish.finalize' => \&finalize,
    );
    $self->kindle_init($context);
}

sub kindle_init {
    my ($self, $context) = @_;
    $self->{context} = $context;
    $self->{id} = time;
    @{$self->{feeds}} = ();
    unless ($self->conf->{work}) {
	$context->error("Can't parse value in work");
    }
    $self->conf->{title} ||= __PACKAGE__;
    $self->conf->{mailfrom} ||= 'plagger@localhost';
}

sub initialize {
    my($self, $context) = @_;

    # authenticate POP before SMTP
    if (my $conf = $self->conf->{pop3}) {
        require Net::POP3;
        my $pop = Net::POP3->new($conf->{host});
        if ($pop->apop($conf->{username}, $conf->{password})) {
            $context->log(info => 'APOP login succeed');
        } elsif ($pop->login($conf->{username}, $conf->{password})) {
            $context->log(info => 'POP3 login succeed');
        } else {
            $context->log(error => 'POP3 login error');
        }
        $pop->quit;
    }
}

sub add {
    my($self, $feed) = @_;
    push @{ $self->{feeds} }, $feed;
}

sub feeds {
    my $self = shift;
    wantarray ? @{ $self->{feeds} } : $self->{feeds};
}

sub feed {
    my($self, $context, $args) = @_;

    my $feed = $args->{feed} or return;
    my $feed_path = File::Spec->catdir($self->conf->{work}, '/feeds/', $feed->id_safe);
    my $publish_path = $feed_path;

    mkpath($publish_path);
    foreach my $entry ($feed->entries) {
	my $entry_id = md5_hex($entry->permalink);
	$self->write(File::Spec->catfile($publish_path, "$entry_id.html"),
		     $self->templatize('kindle_entry.tt', {
                         conf => $self->conf,
                         feed => $feed,
                         entry => $entry,
                     }));

	$entry->{feed2entry_link} = "$entry_id.html";
    }

    $self->add(+{
        id => $feed->id_safe,
        publish_path => './feeds/' . $feed->id_safe,
	title  => $feed->title || '(no-title)',
	lastdate => $feed->entries->[-1]->date,
	count => scalar(@{$feed->entries}),
	entries => [ $feed->entries ],
    });
}

sub finalize {
    my($self, $context, $args) = @_;

    return unless @{$self->feeds};

    my $cfg = $self->conf;
    my $work = $cfg->{work};
    my $modified = Plagger::Date->now(timezone => $context->conf->{timezone});
    my $mobi = md5_hex($self->{id} . $work) . ".mobi";

    $self->write(File::Spec->catfile($work, 'content.opf'),
		 $self->templatize('kindle_opf.tt', {
                     conf => $cfg,
                     feeds => [ $self->feeds ],
                     modified => ($modified),
		     id => md5_hex($self),
		     version => $Plagger::VERSION,
                 }));
    $self->write(File::Spec->catfile($work, 'toc.ncx'),
		 $self->templatize('kindle_ncx.tt', {
                     conf => $cfg,
                     feeds => [ $self->feeds ],
                     modified => ($modified),
                 }));
    $self->write(File::Spec->catfile($work, 'toc.html'),
		 $self->templatize('kindle_toc.tt', {
                     conf => $cfg,
                     feeds => [ $self->feeds ],
                     modified => ($modified),
                 }));

    $self->do_kindlegen($mobi);

    if ($self->conf->{mailto} && -f File::Spec->catfile($work, $mobi)) {
	$context->log(info => "Sending file to $cfg->{mailto}");

	my $subject = $cfg->{title} . " " . $modified->strftime('%Y-%m-%d %H:%M %Z');

	my $msg = MIME::Lite->new(
	    Date => $modified->format('Mail'),
	    From => $cfg->{mailfrom},
	    To   => $cfg->{mailto},
	    Subject => encode('MIME-Header', $subject),
	    Type => 'multipart/related',
	    );
	$msg->replace("X-Mailer" => "Plagger/$Plagger::VERSION");

	$msg->attach(
	    Type => 'application/octet-stream',
	    Path => File::Spec->catfile($work, $mobi),
	    Filename => $mobi,
	);

	my $route = $cfg->{mailroute} || { via => 'smtp', host => 'localhost' };
	$route->{via} ||= 'smtp';

	eval {
	    if ($route->{via} eq 'smtp_tls') {
		$self->{tls_args} = [
		    $route->{host},
		    User     => $route->{username},
		    Password => $route->{password},
		    Port     => $route->{port} || 587,
		    Timeout  => $route->{timeout} || 300,
		    ];
		$msg->send_by_smtp_tls(@{ $self->{tls_args} });
	    } elsif ($route->{via} eq 'sendmail') {
		my %param = (FromSender => "<$cfg->{mailfrom}>");
		$param{Sendmail} = $route->{command} if defined $route->{command};
		$msg->send('sendmail', %param);
	    } else {
		my @args  = $route->{host} ? ($route->{host}) : ();
		$msg->send($route->{via}, @args);
	    }
	};

	if ($@) {
	    $context->log(error => "Error while sending emails: $@");
	}
    }
}

sub write {
    my ($self, $file, $html) = @_;
    open my $out, ">:encoding(utf8)", $file or $self->context->error("$file: $!");
    local $PerlIO::encoding::fallback = Encode::FB_HTMLCREF;
    print $out $html;
    close $out;
}

sub do_kindlegen {
    my ($self, $mobi) = @_;

    my $opf = File::Spec->catfile($self->conf->{work}, 'content.opf');
    my $kindlegen = $self->conf->{kindlegen};
    my $command = qq($kindlegen $opf -o $mobi -unicode);
    system($command);
}

sub DESTORY {
    my $self = shift;
    return unless $self->{tls_args};

    my $conn_key = join "|", @{ $self->{tls_args} };
    eval {
        local $SIG{__WARN__} = sub { };
        $TLSConn{$conn_key} && $TLSConn{$conn_key}->quit;
    };

    # known error from Gmail SMTP
    if ($@ && $@ !~ /An error occurred disconnecting from the mail server/) {
        warn $@;
    }
}

# hack MIME::Lite to support TLS Authentication
*MIME::Lite::send_by_smtp_tls = sub {
    my($self, @args) = @_;
    my $extract_addrs_ref =
        defined &MIME::Lite::extract_addrs
        ? \&MIME::Lite::extract_addrs
        : \&MIME::Lite::extract_full_addrs;

    ### We need the "From:" and "To:" headers to pass to the SMTP mailer:
    my $hdr   = $self->fields();
    my($from) = $extract_addrs_ref->( $self->get('From') );
    my $to    = $self->get('To');

    ### Sanity check:
    defined($to) or Carp::croak "send_by_smtp_tls: missing 'To:' address\n";

    ### Get the destinations as a simple array of addresses:
    my @to_all = $extract_addrs_ref->($to);
    if ($MIME::Lite::AUTO_CC) {
        foreach my $field (qw(Cc Bcc)) {
            my $value = $self->get($field);
            push @to_all, $extract_addrs_ref->($value) if defined($value);
        }
    }

    ### Create SMTP TLS client:
    require Net::SMTP::TLS;

    my $conn_key = join "|", @args;
    my $smtp;
    unless ($smtp = $TLSConn{$conn_key}) {
        $smtp = $TLSConn{$conn_key} = MIME::Lite::SMTP::TLS->new(@args)
            or Carp::croak("Failed to connect to mail server: $!\n");
    }
    $smtp->mail($from);
    $smtp->to(@to_all);
    $smtp->data();

    ### MIME::Lite can print() to anything with a print() method:
    $self->print_for_smtp($smtp);
    $smtp->dataend();

    1;
};

@MIME::Lite::SMTP::TLS::ISA = qw( Net::SMTP::TLS );
sub MIME::Lite::SMTP::TLS::print { shift->datasend(@_) }
1;

__END__

=head1 NAME

Plagger::Plugin::Publish::Kindle - Generate a mobipocket file for Amazon Kindle

=head1 SYNOPSIS

  - module: Publish::Kindle
    config:
      title: Daily News
      work: /path/to/workdir
      kindlegen: /path/to/kindlegen

=head1 DESCRIPTION

This plugin generates a mobipocket file and sends it to your Amazon Kindle.

=head1 CONFIG

=over 4

=item title

Title of mobipocket file.

=item work

Directory to save temporary XHTML files and a mobipocket file in. Required.

=item kindlegen

Specify path of kindlegen command.

=item mailto

Your email address to send updates to.

=item mailfrom

Email address to send email from. Defaults to I<plagger@localhost>.

=item mailroute

Hash to specify how to send emails. Defaults to:

  mailroute:
    via: smtp
    host: localhost

the value of I<via> would be either I<smtp>, I<smtp_tls> or I<sendmail>.

  mailroute:
    via: sendmail
    command: /usr/sbin/sendmail

=back

=head1 AUTHOR

TERAMOTO Masahiro

=head1 SEE ALSO

L<Plagger>, L<MIME::Lite>, L<http://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000234621>

=cut
