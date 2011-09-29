package Plagger::Plugin::Publish::ReadItLater;
use strict;
use base qw( Plagger::Plugin );
use HTTP::Request::Common 'POST';

sub register {
    my ( $self, $context ) = @_;
    $context->register_hook(
        $self,
        'plugin.init'   => \&initialize,
        'publish.entry' => \&add_entry,
    );
}

#sub rule_hook { 'publish.entry' }

sub initialize {
    my ( $self, $context, $args ) = @_;

    $self->{readitlater}->{agent} = Plagger::UserAgent->new;
}

sub add_entry {
    my ( $self, $context, $args ) = @_;

    my $api_url = 'https://readitlaterlist.com/v2/add';

    my $params = {
        api_key  => $self->conf->{api_key},
        username => $self->conf->{username},
        password => $self->conf->{password},
        url      => $args->{entry}->permalink,
        title    => $args->{entry}->title,
    };

    my $req = POST $api_url, $params;
    my $res = $self->{readitlater}->{agent}->request($req);
    if ( $res->is_success ) {
        $context->log( info => "Post entry success" );
    }
    else {
        $context->log( error => $res->header('X-Error') );
    }

    my $sleeping_time = $self->conf->{interval} || 3;
    $context->log( info => "sleep $sleeping_time." );
    sleep($sleeping_time);
}

1;

__END__

=head1 NAME

Plagger::Plugin::Publish::ReadItLater - Post to ReadItLater automatically

=head1 SYNOPSIS

  - module: Publish::ReadItLater
    config:
      username: your-username
      password: your-password
      api_key: your-apikey
      interval: 2

=head1 DESCRIPTION

This plugin posts feed updates to Read It later, using its API.

=head1 CONFIGURATION

=over 4

=item username, password

Your login and password for logging in ReadItLater.

=item api_key

Your api_key in ReadItLater. You can get it at http://readitlaterlist.com/api/.

=item interval

Interval (as seconds) to sleep after posting each url. Defaults to 3.

=back

=cut

=head1 AUTHOR

MATSUI Shinsuke

=head1 SEE ALSO

L<Plagger>, L<http://readitlaterlist.com/>

=cut
