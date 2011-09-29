use Plagger::Util qw( decode_content );

sub handle_force {
    my($self, $args) = @_;
    return $args->{entry}->link =~ m|http://ascii\.jp/elem/\d{3}/\d{3}/\d{3}/\d{6}/|;
}

sub extract {
    my($self, $args) = @_;
    my $content;

    if ($args->{entry}->link =~ /summary\.html/) {
        my $url = $args->{entry}->link;
        $url =~ s/summary\.html//;
        my $ua = Plagger::UserAgent->new;
        my $res = $ua->get($url);
        return if $res->is_error;
        $content = decode_content($res->content);
    } else {
        $content = $args->{content};
    }

    if ($content =~ m|</h1>(.*?)<!--  google_ad_section_end(name=s1)  -->|xms) {
        return "<div>$1</div>";
    }
    return;
}
