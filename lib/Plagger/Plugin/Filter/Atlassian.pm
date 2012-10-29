package Plagger::Plugin::Filter::Atlassian;
use strict;
use base qw( Plagger::Plugin );


sub apply_tags {
    my ($self, $entry) = @_;
    
    return unless $self->conf->{tag};
    $entry->tags([$self->conf->{tag}]);
    
}

1;