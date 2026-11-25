#-------
# perl-vue-blog/backend/app.pl
#-------
use lib 'lib';
use Mojolicious::Lite -signatures;
use Blog::Service::PostService;

my %parm=('db_path'=>'blog.db');

#my $service = Blog::Service::PostService->new('blog.db');
my $service = Blog::Service::PostService->new(%parm);

# CORSヘッダーの付与（開発用）
app->hook(before_dispatch => sub ($c) {
    $c->res->headers->header('Access-Control-Allow-Origin' => '*');
    $c->res->headers->header('Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS');
    $c->res->headers->header('Access-Control-Allow-Headers' => 'Content-Type');
    if ($c->req->method eq 'OPTIONS') {
        $c->render(text => '', status => 200);
    }
});

# 記事一覧取得 API
#get '/api/posts' => sub ($c) {
#    my $posts = $service->get_all_posts();
#    $c->render(json => $posts);
#};

# ページネーション＋キーワード検索対応の記事一覧取得 API (/api/posts?page=1&q=キーワード)
get '/api/posts' => sub ($c) {
    my $page = $c->param('page') // 1;
    my $q        = $c->param('q') // '';
    my $per_page = 5; # 1ページあたり5件
    my $result = $service->get_posts_paginated($page, $per_page, $q);
    $c->render(json => $result);
};

# 記事投稿 API
post '/api/posts' => sub ($c) {
    my $json = $c->req->json;
    eval {
        my $post = $service->create_post($json->{yname}, $json->{title}, $json->{content}, $json->{password}, $json->{email});
        #my $post = $service->create_post($json->{title}, $json->{content});
        $c->render(json => $post, status => 201);
    };
    if ($@) {
        $c->render(json => { error => $@ }, status => 400);
    }
};

# 記事削除 API (/api/posts/123)
del '/api/posts/:id' => sub ($c) {
    my $id = $c->param('id');
    eval {
        $service->delete_post($id);
        $c->render(json => { deleted => \1, id => int($id) }, status => 200);
    };
    if ($@) {
        $c->render(json => { error => $@ }, status => 404);
    }
};

# 記事修正 API (/api/posts/123)
put '/api/posts/:id' => sub ($c) {
    my $id = $c->param('id');
    my $json = $c->req->json;
    eval {
        my $post = $service->update_post($id, $json->{yname}, $json->{title}, $json->{content}, $json->{password}, $json->{email});
        #my $post = $service->update_post($id, $json->{title}, $json->{content});
        $c->render(json => $post, status => 200);
    };
    if ($@) {
        $c->render(json => { error => $@ }, status => 400);
    }
};


app->config(hypnotoad => { listen => ['http://*:3000'] });
app->start;

