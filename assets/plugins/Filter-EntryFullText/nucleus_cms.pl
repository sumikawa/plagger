# author: Shinsuke Matsui
sub handle {
    my($self, $args) = @_;
    return 1 if $args->{content} =~ m!<meta name="generator" content="Nucleus CMS!si;
    return;
}

sub extract {
    my($self, $args) = @_;
    if ($args->{content} =~ m#<div class="textBody">(.*?)</div>.*?<div class="textBody" id="extended">(.*?)</div>#s) {
        return "<div>$1</div><div>$2</div>";
    }
    elsif ($args->{content} =~ m#<div class="entry">(.*?)</div>#s) {
        return $1;
    }
    return;
}
