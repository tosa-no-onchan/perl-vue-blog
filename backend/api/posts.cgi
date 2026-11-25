#!/usr/bin/perl
#----
# perl-vue-blog/backend/api/posts.cgi
#----
use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use File::Spec;
use lib File::Spec->catdir($RealBin, '..', 'lib'), $RealBin;

use File::Spec;
use MyApp::ToolMy;

use Cgi::JsonApi;
use Blog::Service::PostService;

#MyApp::ToolMy::exitError("psost.cgi : #1 passed!!");

my $cgi = Cgi::JsonApi->new(
    max_body_bytes => 1_048_576,
);

#print("psost.cgi : #1 passed!!");

exit 0 if $cgi->handle_options_if_needed();

my $db_path = File::Spec->catfile($RealBin, '..', 'blog.db');

#print("post.cgi :#2 \$db_path:".$db_path."\n");

my %parm=('db_path'=>$db_path);
my $service = Blog::Service::PostService->new(%parm);

eval {
    my $method = $cgi->method();
    my $query  = $cgi->query_params();

    if ($method eq 'GET') {
        my $page     = $query->{page} // 1;
        my $q        = $query->{q}    // '';
        my $per_page = 5;
        my $result   = $service->get_posts_paginated($page, $per_page, $q);
        $cgi->send_json('200 OK', $result);
    }
    elsif ($method eq 'POST') {
        my $body = $cgi->json_body();
        my $post = $service->create_post($body->{yname}, $body->{title}, $body->{content}, $body->{password}, $body->{email});
        $cgi->send_json('201 Created', $post);
    }
    elsif ($method eq 'PUT') {
        my $id   = $query->{id};
        my $body = $cgi->json_body();
        my $post = $service->update_post($id, $body->{yname}, $body->{title}, $body->{content}, $body->{password}, $body->{email});
        $cgi->send_json('200 OK', $post);
    }
    elsif ($method eq 'DELETE') {
        my $id = $query->{id};
        my $body = $cgi->json_body();
        #$service->delete_post($id);
        $service->delete_post($id, $body->{password});
        $cgi->send_json('200 OK', { deleted => JSON::PP::true, id => int($id) });
    }
    else {
        die "Method not allowed: $method\n";
    }
};
if ($@) {
    $cgi->send_error($@);
}

exit 0;





