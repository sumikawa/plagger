package Plagger::Plugin::Filter::RegexpTitle;
use strict;
use base qw( Plagger::Plugin );
use Encode;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'update.entry.fixup' => \&filter,
    );
}

sub filter {
    my($self, $context, $args) = @_;

    local $_ = $args->{entry}->title;
    my $regexp = decode_utf8($self->conf->{regexp}, Encode::FB_CROAK);
    my $count = eval $regexp;
    if ($@) {
        Plagger->context->log(error => "Error: $@ in " . $self->conf->{regexp});
        return;
    }
    $args->{entry}->title($_) if($count);
}

1;
