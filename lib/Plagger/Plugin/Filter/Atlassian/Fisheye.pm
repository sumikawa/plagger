package Plagger::Plugin::Filter::Atlassian::Fisheye;
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
    my $project = $self->conf->{project_name};
    return unless $args->{entry}->title =~ m!^$project!i;
    
    # Now to fix up title
    my $title = $args->{entry}->title;
    $context->log(debug => 'Fisheye title: ' . $title) if $self->conf->{debug};
    
    my ($branch, $rev, $user, $log_msg) = ($title =~ m|^$project\s+(\S+)\s+#(\d+):\s+\[(.*?)\]\s+(.*)|);
    $context->log(debug => 'USER: ' . $user . '   REV: ' . $rev . "  BRANCH: " . $branch . "  MSG: " . $log_msg) if $self->conf->{debug};
    
    $args->{entry}->title("#$rev ($branch): $log_msg");

    $args->{entry}->author($user);
    
    $self->apply_tags($args->{entry});
    
}

1;
__END__

=head1 NAME

Plagger::Plugin::Filter::Atlassian::Fisheye -

=head1 SYNOPSIS

  - module: Filter::Atlassian::Fisheye

=head1 DESCRIPTION

XXX Write the description for Filter::Atlassian::Fisheye

=head1 CONFIG

XXX Document configuration variables if any.

=head1 AUTHOR

Andreas Marienborg

=head1 SEE ALSO

L<Plagger>

=cut
