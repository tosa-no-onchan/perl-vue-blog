package MyApp::ToolMy;
use strict;
use warnings;
use Data::Dumper;

sub encode_htcode{
    my($val) = @_;
    $val =~ s/\-\-/&#45;&#45;/g;
    $val =~ s/</&lt;/g;                 # 小なり
    $val =~ s/>/&gt;/g;                 # 大なり
    $val =~ s/"/&quot;/g;               # ダブルクォート
    $val =~ s/'/&#39;/g;               # シングルクォート（独自）
    $val =~ s/=/&#61;/g;               # イコール（独自）
    return $val;
}

# こちらは、Debug 用です!!
sub spred_array{
    my($val) = @_;
    # 配列リファレンスの場合: [val1, val2] の形にする
    #my @items = map { defined $_ ? $_ : 'undef' } @$val;
    #my $s;
    my @list;
    my $cnt=0;
    #foreach my $item (@items) {
    foreach my $item (@$val) {
        if (!defined $item) {
            push @list, 'undef';
        }
        elsif(ref($item) eq 'HASH'){
            my $s = spred_hash($item);
            push @list,$s;
        }
        elsif(ref($item) eq 'ARRAY'){
            my $s=spred_array($item);
            push @list,$s;
        }
        else{
            push @list,$item;
        }
        $cnt++;
        if($cnt > 500){
            last;
        }
    }
    return '[' . join(', ', @list) . ']';
}

sub spred_hash{
    my($val) = @_;
    my @parts;
    #my $s;
    my  $cnt=0;
    foreach my $k (keys %$val) {
        if (!defined $k) {
            push @parts, 'undef';
        }
        elsif(ref($val->{$k}) eq 'HASH'){
            my $s = spred_hash($val->{$k});
            push @parts,"{$k=>".$s."}";
        }
        elsif(ref($val->{$k}) eq 'ARRAY'){
            my $s=spred_array($val->{$k});
            push @parts,"{$k=>".$s."}";
        }
        else{
            push @parts,"{$k=>".$val->{$k}."}";
        }
        $cnt++;
        if($cnt > 500){
            last;
        }
   }
    my $s = join(' ', @parts);
    return $s;
}

sub spred_all{
    my($val) = @_;
    my $s;
    if(ref($val) eq 'HASH'){
        $s=spred_hash($val);
    }
    elsif(ref($val) eq 'ARRAY'){
        $s=spred_array($val);
    }
    else{
        $s=$val;
    }
    return $s;
}

sub my_dumper{
    my($msg,$short) = @_;
    #use Data::Dumper;
    # データの改行やインデントを綺麗にする設定
    if($short){
        local $Data::Dumper::Indent = 1; 
    }
    else{
        local $Data::Dumper::Indent = 1; 
        local $Data::Dumper::Terse  = 1;
    }

    #my @arguments = $app->search_terms();

    # --- ここから追加 ---
    # @arguments全体の構造がそのまま文字列として $s に入ります
    my $s = Dumper($msg);
    $s;
}

sub exitError
{
    my($msg,$flg) = @_;
    if(!$flg){
        $msg =~ s/\n/<br \/>\n/g;
    }
    print <<END_OF_ERR_HTML;
Content-Type: text/html

<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<title>error</title>
</head>
<body>
<font color="#FF0000">$msg</font><br />
<font color="#0000FF">$!</font>
</body>
</html>
END_OF_ERR_HTML
    exit(1);    
}

1;