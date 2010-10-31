# author: poppen
sub handle {
    my($self, $args) = @_;
    $args->{entry}->link =~ qr!^http://ya\.maya\.st/d/\d{6}\w\.html#.*$!;
}
sub extract {
    my ($self, $args) = @_;
    if ($args->{entry}->link =~ m!#(.*)$!) {
        my $fragment = $1;
        if ($args->{content} =~ m|<h3\sid="\Q$fragment\E">.*?</h3>.*?<blockquote>(.*?)</blockquote>|is) {
            my $body = $1;
            return "<div>$body</div>";
        }
    }
    return;
}
