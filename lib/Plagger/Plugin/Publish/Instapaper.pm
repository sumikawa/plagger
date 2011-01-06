package Plagger::Plugin::Publish::Instapaper;
use strict;
use base qw( Plagger::Plugin );

use WWW::Instapaper::Client;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'plugin.init'   => \&initialize,
        'publish.entry' => \&add_entry,
    );
}

sub rule_hook { 'publish.entry' }

sub initialize {
    my ($self, $context, $args) = @_;
    $self->{paper} = WWW::Instapaper::Client->new({
        username => $self->conf->{username},
        password => $self->conf->{password},
    });
}

sub add_entry {
    my($self, $context, $args) = @_;

    my $params = {
        url         => $args->{entry}->permalink,
        title       => $args->{entry}->title,
    };

    if ($self->conf->{post_summary}) {
        $params->{selection} = $args->{entry}->summary,
    }

    $self->{paper}->add(%{$params});

    my $sleeping_time = $self->conf->{interval} || 3;
    $context->log(info => "Post entry success. sleep $sleeping_time.");
    sleep( $sleeping_time );
}

1;

__END__

=head1 NAME

Plagger::Plugin::Publish::Instapaper - Post to Instapaper automatically

=head1 SYNOPSIS

  - module: Publish::Instapaper
    config:
      username: your-username
      password: your-password
      interval: 2
      post_summary: 1

=head1 DESCRIPTION

This plugin posts feed updates to Instapaper, using its REST API.

=head1 CONFIGURATION

=over 4

=item username, password

Your login and password for logging in Instapaper.

=item interval

Interval (as seconds) to sleep after posting each url. Defaults to 3.

=item post_summary

A flag to post entry's summary as selection field for Instapaper. Defaults to 0.

=back

=cut

=head1 AUTHOR

TERAMOTO Masahiro

=head1 SEE ALSO

L<Plagger>, L<WWW::Client::Instapaper>, L<http://www.instapaper.com/>

=cut
