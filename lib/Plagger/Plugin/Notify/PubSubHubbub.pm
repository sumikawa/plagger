package Plagger::Plugin::Notify::PubSubHubbub;

use strict;
use base qw( Plagger::Plugin );

use Net::PubSubHubbub::Publisher;

sub register {
    my ( $self, $context ) = @_;
    $context->register_hook(
        $self,
        'publish.entry' => \&update,
        'publish.finalize' => \&finalize,
    );
    $self->{count} = 0;
}

sub update {
    my($self, $context, $args) = @_;
    $self->{count}++ if $args->{feed}->count;
}

sub finalize {
    my($self, $context, $args) = @_;

    if ($self->{count}) {
	if ((my $hub = $self->conf->{hub}) && (my $s = $self->conf->{self})) {
	    $context->log(info => "Notifying " . $s . " to " . $hub);
	    my $pub = Net::PubSubHubbub::Publisher->new(hub => $hub);
	    $pub->publish_update($s) or
		die "Ping failed: " . $pub->last_response->status_line;
	    $context->log(info => "Status: " . $pub->last_response->status_line);
	}
    }
}

1;

__END__

=head1 NAME

Plagger::Plugin::Notify::PubSubHubbub - Notify PubSubHubbub hub of feed updates.

=head1 SYNOPSIS

  - module: Notify::PubSubHubbub
    config:
      hub: http://pubsubhubbub.appspot.com/
      self: http://example.com/foo.xml

=head1 DESCRIPTION

This plugin notifies PubSubHubbub hub of feed updates.

=head1 AUTHOR

YOSHIDA Hideki

=head1 SEE ALSO

L<Plagger>, L<Net::PubSubHubbub::Publisher>

=cut
