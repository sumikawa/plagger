package Plagger::Plugin::Filter::NCR;
use strict;
use warnings;
use base qw( Plagger::Plugin::Filter::Base );

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'update.entry.fixup' => \&update,
    );
}

sub update {
    my($self, $context, $args) = @_;
    my $body = $args->{entry}->body;
    my $title = $args->{entry}->title;

    $title = ncr_filter($title);
    $body = ncr_filter($body);

    $args->{entry}->title($title);
    $args->{entry}->body($body);
}

sub ncr_filter {
    my $text = shift;

    # this line is copied from http://as-is.net/blog/archives/001121.html
    $text =~ s/(\P{ASCII})/sprintf("&#%d;", ord($1))/eg;

    $text;
}

1;
