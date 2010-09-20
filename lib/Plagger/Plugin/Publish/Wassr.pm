package Plagger::Plugin::Publish::Wassr;
use strict;
use base qw( Plagger::Plugin );

use Encode;
use Net::Wassr;
use Time::HiRes qw(sleep);

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'publish.entry' => \&publish_entry,
        'plugin.init'   => \&initialize,
    );
}

sub initialize {
    my($self, $context) = @_;
    my %opt = (
        user => $self->conf->{username},
        passwd => $self->conf->{password},
    );
    for my $key (qw/ apihost apiurl apirealm/) {
        $opt{$key} = $self->conf->{$key} if $self->conf->{$key};
    }
    $self->{wassr} = Net::Wassr->new(%opt);
}

sub publish_entry {
    my($self, $context, $args) = @_;
    my $body = $args->{entry}->body_text;

    if ($self->conf->{templatize}) {
	$body = $self->templatize('wassr.tt', $args);
    }

    # TODO: FIX when Summary configurable.
    if ( length($body) > 159 ) {
        $body = substr($body, 0, 159);
    }
    $context->log(info => "Updating Wassr status to '$body'");
    if ($self->conf->{channel}) {
	$self->{wassr}->channel_update( {name_en => $self->conf->{channel}, body => encode_utf8($body)} ) or $context->error("Can't update wassr status");
    } else {
	$self->{wassr}->update( {status => encode_utf8($body)} ) or $context->error("Can't update wassr status");
    }
    my $sleeping_time = $self->conf->{interval} || 15;
    $context->log(info => "sleep $sleeping_time.");
    sleep( $sleeping_time );
}

1;
__END__

=head1 NAME

Plagger::Plugin::Publish::Wassr - Update your status with feeds

=head1 SYNOPSIS

  - module: Publish::Wassr
    config:
      username: wassr-id
      password: wassr-password
      channel: name_en
      templatize: 1

=head1 DESCRIPTION

This plugin sends feed entries summary to your Wassr account status.

=head1 CONFIG

=over 4

=item username

Wassr username. Required.

=item password

Wassr password. Required.

=item interval

Optional.

=item apiurl

OPTIONAL. The URL of the API for wassr.jp. This defaults to "http://wassr.jp/user/xxx/statuses" if not set.

=item apihost

=item apirealm

Optional.
If you do point to a different URL, you will also need to set "apihost" and "apirealm" so that the internal LWP can authenticate.

    "apihost" defaults to "api.wassr.jp:80".
    "apirealm" defaults to "API Authentication".

=back

=head1 AUTHOR

Yasuhiro Matsumoto
SHIBATA Hiroshi

=head1 SEE ALSO

L<Plagger>, L<Net::Wassr>

=cut
