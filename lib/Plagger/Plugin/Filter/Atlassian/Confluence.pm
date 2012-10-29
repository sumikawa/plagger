package Plagger::Plugin::Filter::Atlassian::Confluence;
use strict;
use base qw( Plagger::Plugin::Filter::Atlassian );

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'update.entry.fixup' => \&filter,
    );
}
sub filter {
    my($self, $context, $args) = @_;
    
    my $base = $self->conf->{baseurl};
    return unless $args->{entry}->link =~ m!^$base!i;
    
    # Now to fix up title
    my $title = $args->{entry}->title;
    $context->log(debug => 'Confluence title: ' . $title) if $self->conf->{debug};
 
    
#    my ($branch, $rev, $user, $log_msg) = ($title =~ m|^$project\s+(\S+)\s+#(\d+):\s+\[(.*?)\]\s+(.*)|);
#    $context->log(debug => 'USER: ' . $user . '   REV: ' . $rev . "  BRANCH: " . $branch . "  MSG: " . $log_msg) if $self->conf->{debug};
#    
#    $args->{entry}->title($title);


    $self->apply_tags($args->{entry});
}
1;
__END__

=head1 NAME

Plagger::Plugin::Filter::Atlassian::Confluence -

=head1 SYNOPSIS

  - module: Filter::Atlassian::Confluence

=head1 DESCRIPTION

XXX Write the description for Filter::Atlassian::Confluence

=head1 CONFIG

XXX Document configuration variables if any.

=head1 AUTHOR

Andreas Marienborg

=head1 SEE ALSO

L<Plagger>

=cut
