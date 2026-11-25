#----
# backend/lib/Cgi/JsonApi.pm
#----
package Cgi::JsonApi;
use strict;
use warnings;
use utf8;
use Encode ();
use JSON::PP qw(decode_json);

sub new {
    my ($class, %args) = @_;
    return bless {
        allowed_origin => $args{allowed_origin}, # 未指定なら HTTP_ORIGIN または '*'
        allowed_methods => $args{allowed_methods} // 'GET, POST, PUT, DELETE, OPTIONS',
        allowed_headers => $args{allowed_headers} // 'Content-Type',
        max_body_bytes  => $args{max_body_bytes}  // 1_048_576, # デフォルト 1MB
    }, $class;
}

sub method {
    my ($self) = @_;
    return uc($ENV{REQUEST_METHOD} || 'GET');
}

sub query_params {
    my ($self) = @_;
    my $qs = $ENV{QUERY_STRING};
    my %params;
    return \%params unless defined $qs && $qs ne '';

    for my $pair (split /&/, $qs) {
        next if $pair eq '';
        my ($k, $v) = split /=/, $pair, 2;
        $k //= '';
        $v //= '';
        $k =~ tr/+/ /;
        $v =~ tr/+/ /;
        $k =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        $v =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        utf8::decode($k) unless utf8::is_utf8($k);
        utf8::decode($v) unless utf8::is_utf8($v);
        $params{$k} = $v;
    }
    return \%params;
}

sub json_body {
    my ($self) = @_;
    my $len = $ENV{CONTENT_LENGTH};
    return {} unless defined $len && $len ne '';
    die "Invalid CONTENT_LENGTH\n" unless $len =~ /^\d+$/;
    return {} if $len == 0;
    die "Request body too large\n" if $len > $self->{max_body_bytes};

    binmode(STDIN);
    my $buf = '';
    my $total_read = 0;
    while ($total_read < $len) {
        my $chunk = '';
        my $n = read(STDIN, $chunk, $len - $total_read);
        last if !defined($n) || $n == 0;
        $buf .= $chunk;
        $total_read += $n;
    }
    die "Incomplete request body\n" if $total_read != $len;

    my $utf8_bytes = utf8::is_utf8($buf) ? Encode::encode('UTF-8', $buf) : $buf;
    my $data = eval { decode_json($utf8_bytes) };
    if ($@ || ref($data) ne 'HASH') {
        die "Invalid JSON body\n";
    }
    return $data;
}

sub _resolve_origin {
    my ($self) = @_;
    return $self->{allowed_origin} if defined $self->{allowed_origin} && $self->{allowed_origin} ne '';
    return $ENV{HTTP_ORIGIN} || '*';
}

sub _print_cors_headers {
    my ($self) = @_;
    my $origin = $self->_resolve_origin();
    print "Access-Control-Allow-Origin: $origin\r\n";
    print "Access-Control-Allow-Methods: $self->{allowed_methods}\r\n";
    print "Access-Control-Allow-Headers: $self->{allowed_headers}\r\n";
}

sub handle_options_if_needed {
    my ($self) = @_;
    return 0 unless $self->method eq 'OPTIONS';

    binmode(STDOUT, ':raw');
    print "Status: 200 OK\r\n";
    $self->_print_cors_headers();
    print "\r\n";
    return 1;
}

sub send_json {
    my ($self, $status, $payload) = @_;
    $status //= '200 OK';

    my $json = JSON::PP->new->utf8->convert_blessed(1);
    my $json_text = $json->encode($payload);

    binmode(STDOUT, ':raw');
    print "Status: $status\r\n";
    print "Content-Type: application/json; charset=UTF-8\r\n";
    $self->_print_cors_headers();
    print "\r\n";
    print $json_text;
    print "\n";
    return;
}

sub send_error {
    my ($self, $err_msg, $status) = @_;
    my $msg = defined $err_msg ? "$err_msg" : 'Bad Request';
    $msg =~ s/\s+$//;

    if (!defined $status) {
        if ($msg =~ /not found/i) {
            $status = '404 Not Found';
        }
        elsif ($msg =~ /method not allowed/i) {
            $status = '405 Method Not Allowed';
        }
        elsif ($msg =~ /too large/i) {
            $status = '413 Payload Too Large';
        }
        else {
            $status = '400 Bad Request';
        }
    }

    $self->send_json($status, { error => $msg });
    return;
}

1;

