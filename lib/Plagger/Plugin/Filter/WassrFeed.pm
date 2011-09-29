package Plagger::Plugin::Filter::WassrFeed;
use strict;
use base qw( Plagger::Plugin );

our $VERSION = '0.01';

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'update.entry.fixup' => \&filter,
    );
}

sub filter {
    my($self, $context, $args) = @_;

    return unless $args->{feed}->url =~ m!^http://api\.wassr\.jp/!;
    $context->log(debug => "Found Wassr feed " . $args->{feed}->url);

    # strip username in title
    if ($args->{entry}->title =~ /^(.*)?:\ (.*)?$/) {
	my $strip_title = $args->{entry}->title;
	$strip_title =~ s/^(.*)?:\ //g;
	$args->{entry}->title($strip_title);
	$context->log(info => "Strip username in title: " . $args->{entry}->title);
    }
}

1;

__END__

=head1 NAME

Plagger::Plugin::Filter::WassrFeed -

=head1 SYNOPSIS

- module: Filter::WassrFeed

=head1 DESCRIPTION

=head1 CONFIG

=head1 AUTHOR

SHIBATA Hiroshi

=head1 SEE ALSO

L<Plagger>

=cut
