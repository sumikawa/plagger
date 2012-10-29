package Plagger::Plugin::Filter::Atlassian::JIRA;
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
    $context->log(debug => 'JIRA title: ' . $title) if $self->conf->{debug};
    
    my ($user, $key, $title) = ($title =~ m|name=(.*?)'>.*>([A-Z]+-\d+)<.*\((.*?)\)|);
    $context->log(debug => 'USER: ' . $user . '   KEY: ' . $key . "   TITLE: " . $title) if $self->conf->{debug};
    
    $args->{entry}->title("$key: $title");
    $args->{entry}->author($user);
    
    $self->apply_tags($args->{entry});

}

1;
__END__

=head1 NAME

Plagger::Plugin::Filter::Atlassian::JIRA -

=head1 SYNOPSIS

  - module: Filter::Atlassian::JIRA

=head1 DESCRIPTION

XXX Write the description for Filter::Atlassian::JIRA

=head1 CONFIG

XXX Document configuration variables if any.

=head1 AUTHOR

Andreas Marienborg

=head1 SEE ALSO

L<Plagger>

=cut
