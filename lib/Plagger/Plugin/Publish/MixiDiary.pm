package Plagger::Plugin::Publish::MixiDiary;
use strict;
use warnings;
use base qw ( Plagger::Plugin );

use WWW::Mixi;
use Encode;
use Time::HiRes qw(sleep);

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'publish.init'  => \&initialize,
        'publish.entry' => \&post_diary,
    );
}

sub initialize {
    my($self, $context, $args) = @_;

    my $cookie_jar = $self->cookie_jar;
    if (ref($cookie_jar) ne 'HTTP::Cookies') {
        $self->conf->{username} ||= 'email@example.com',
        $self->conf->{password} ||= 'p4ssw0rd',
    }

    $self->{mixi} = WWW::Mixi->new(
        $self->conf->{username},
        $self->conf->{password},
        -log => 0,
    );
    $self->{mixi}->cookie_jar($cookie_jar);

    unless ($self->{mixi}->login) {
        $context->log(error => "Login failed.");
    } else {
        $context->log(info => "Login Successed.");
    }
}

sub post_diary {
    my($self, $context, $args) = @_;

    my $e = $args->{entry};

    my $title = $e->title;
    my $body  = $e->body_text;
    my $linkurl = $e->link;
    my $memo = "-------------------------------\n originally posted on Your Blog\n";
    #$body = $body."\n\n".$memo.$linkurl; # $body plus quotation
    my @images;

    if ($e->has_enclosure) {
        for my $enclosure (grep { defined $_->url 
            && $_->is_inline 
            && ($_->url =~ /.*\.jpg$/) } $e->enclosure) {
            push(@images, $enclosure->local_path);
        }
    }

    my %diary = (
        diary_title => encode('euc-jp', $title),
        diary_body  => encode('euc-jp', $body),
        photo1      => shift(@images),
        photo2      => shift(@images),
        photo3      => shift(@images),
    );

    my $sleeping_time = $self->conf->{interval} || 3;
    if ($self->{mixi}->get_add_diary_confirm(%diary)) {
        $context->log(info => "Making diary succeeded.");
    } else {
        $context->log(error => "Making diary failed.");
    }
}

1;
__END__

=hea1 NAME

Plagger::Plugin::Publish::MixiDiary - publish mixi diary

=head1 SYNOPSIS

  - module: Publish::MixiDiary
      config:
            username: email@example.com
            password: p4ssw0rd
            interval: 10

=head1 DESCRIPTION

This plugin posts entry to mixi diary.

=over 4

=item username, password

Your e-mail and password for logging in mixi

=back

=cut

=head1 AUTHOR

Tsuyoshi Maekawa

=head1 SEE ALSO

L<Plagger>, L<WWW::Mixi>, L<http://mixi.jp/>

=cut
