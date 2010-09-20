package Plagger::Plugin::Filter::AssembleEntries;
use strict;
use base qw( Plagger::Plugin );

use Plagger::Entry;
use utf8;
use Encode;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'update.entry.fixup' => \&assemble,
        'update.feed.fixup' => \&finalize,
    );
}

sub assemble {
    my($self, $context, $args) = @_;
    my $body = $args->{entry}->body->plaintext;
    my $del_word = $self->conf->{del_word} || undef;
    $body =~ s/$del_word// if($del_word);

    if($self->conf->{timelabel} && $self->conf->{timelabel} =~ /(:?ymd|hms)/){
        my $tz = $self->conf->{timezone} || 'local';
        my $time = $args->{entry}->date->set_time_zone($tz);
        my $label = $time->ymd." ".$time->hms;
        $label = $time->ymd if($self->conf->{timelabel} eq 'ymd');
        $label = $time->hms if($self->conf->{timelabel} eq 'hms');
        push @{$self->conf->{assemble}}, $label." ".$body;
    }else{
        push @{$self->conf->{assemble}}, $body;
    }
}

sub finalize {
    my($self, $context, $args) = @_;
    
    $context->log(debug => "Assembling Entries");
    
    my $title = $self->conf->{title} || "Assembled Entry";
    my $link = $self->conf->{link} || "No Link";
    my $delimiter = $self->conf->{delimiter} || "<br />";
    my $reverse = $self->conf->{reverse} || undef;
    my $empty_msg = $self->conf->{empty_msg} || "This Feed have No Matched Entry.";
    my $tz = $self->conf->{timezone} || 'local';
    
    if(defined $self->conf->{assemble} && $reverse){
        my @rev = reverse @{$self->conf->{assemble}};
        $self->conf->{assemble} = \@rev;
    }

    my $e = Plagger::Entry->new;
    $e->title(_u($title));
    $e->permalink(_u($link));
    
    if(defined @{$self->conf->{assemble}}){
        $e->body(join $delimiter, @{$self->conf->{assemble}});
    }else{
        $e->body($empty_msg);
    }
    $e->date(Plagger::Date->now($tz));

    $args->{feed}->{entries} = [$e];
}

sub _u {
    my $str = shift;
    Encode::_utf8_on($str);
    $str;
}

1;
__END__

=head1 NAME

Plagger::Plugin::Filter::AssembleEntries - Assemble entries in feed

=head1 SYNOPSIS

  - module: Filter::AssembleEntries
    config:
      title: Title of The Assembled Entry
      link: http://example.com/
      delimiter: <br />
      reverse: 1
      timelabel: ymd
      del_word: WORD
      empty_msg: Oops!

=head1 DESCRIPTION

This plugin is to assemble entries in Feed.

=head1 AUTHOR

Toshi

=cut
