package Plagger::Plugin::Filter::RSSBaiduJpDateTime;
use strict;
use base qw( Plagger::Plugin );
use Plagger::Date;
use Encode;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'aggregator.filter.feed' => \&filter,
    );
}

sub filter {
    my($self, $context, $args) = @_;
    $args->{content} =~
        s{<(pubDate|lastBuildDate)>(?:<!\[CDATA\[)?(.+?)(?:\]\]>)?</\1>}
        {"<$1>" . $self->fixup_datetime($2) . "</$1>"}eg;
}

sub fixup_datetime {
    my($self, $date) = @_;

    my $valid = eval { DateTime::Format::Mail->parse_datetime($date) };
    return $date if $valid;

    my $dt = Plagger::Date->strptime('%Y年%m月%d日 %H:%M', decode_utf8($date))
        or return $date;

    my $rfc822 = DateTime::Format::Mail->format_datetime($dt);
    Plagger->context->log(info => "Fix $date to $rfc822");
    $rfc822;
}

1;
__END__

=head1 NAME

Plagger::Plugin::Filter::RSSBaiduJpDateTime - Fix datetaime of Baidu.JP

=head1 SYNOPSIS

  - module: Filter::RSSBaiduJpDateTime

=head1 DESCRIPTION

This plugin fixes a datetime format pubDate and lastBuildDate of Baidu.JP.

=head1 AUTHOR

Masakazu Takahashi

=head1 SEE ALSO

L<Plagger>

=cut
