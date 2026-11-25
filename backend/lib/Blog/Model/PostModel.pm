#----
# perl-vue-blog/backend/lib/Blog/Model/PostModel.pm
#----
package Blog::Model::PostModel;
use strict;
use warnings;

#use Mojo::Base -strict;
use DBI;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Blog::Entity::Post;

# new 2026.11.22
sub new {
    my ($class, %args) = @_;
    my $db_path = $args{db_path} or die "PostModel::new :#1 db_path is required\n";
    my $dir = dirname($db_path);
    make_path($dir) unless -d $dir;

    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$db_path",
        "",
        "",
        {
            RaiseError     => 1,
            PrintError     => 0,
            AutoCommit     => 1,
            sqlite_unicode => 1,
        }
    ) or die $DBI::errstr;

    my $self = bless {
        db_path => $db_path,
        dbh     => $dbh,
    }, $class;

    $self->_init_table();
    return $self;
}

# new 2026.11.22
sub _init_table {
    my ($self) = @_;
    my $dbh = $self->{dbh};
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS posts (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            yname      TEXT NOT NULL,
            title      TEXT NOT NULL,
            content    TEXT NOT NULL,
            password   TEXT NOT NULL DEFAULT '',
            email      TEXT NOT NULL DEFAULT '',
            time_stamp INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
        )
    });

    # 既存テーブルに不足しているカラムがあれば追加（マイグレーション）
    my %existing_cols;
    my $sth = $self->{dbh}->prepare("PRAGMA table_info(posts)");
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref()) {
        $existing_cols{ $row->{name} } = 1;
    }
    $sth->finish();

    $dbh->do("ALTER TABLE posts ADD COLUMN yname TEXT NOT NULL DEFAULT ''")
        unless $existing_cols{yname};
    $dbh->do("ALTER TABLE posts ADD COLUMN password TEXT NOT NULL DEFAULT ''")
        unless $existing_cols{password};
    $dbh->do("ALTER TABLE posts ADD COLUMN email TEXT NOT NULL DEFAULT ''")
        unless $existing_cols{email};
    $dbh->do("ALTER TABLE posts ADD COLUMN time_stamp INTEGER NOT NULL DEFAULT 0")
        unless $existing_cols{time_stamp};
}

# new 2026.11.22
# パスワード照合（一致すれば真を返す）
sub verify_password {
    my ($self, $id, $input_password) = @_;
    return 0 unless defined $id && $id =~ /^\d+$/;

    my $post = $self->find_by_id($id);
    return 0 unless $post;

    my $stored_pw = $post->{password} // '';
    my $given_pw  = defined $input_password ? "$input_password" : '';

    return ($stored_pw eq $given_pw) ? 1 : 0;
}

# new 2026.11.22
# 1件取得（password も内部判定用に取得する。JSON 返却時は Service / Entity 側で除外）
sub find_by_id {
    my ($self, $id) = @_;
    return undef unless defined $id && $id =~ /^\d+$/;

    my $sth = $self->{dbh}->prepare(q{
        SELECT id, yname, title, content, password, email, time_stamp, created_at
        FROM posts
        WHERE id = ?
    });
    $sth->execute($id);
    my $row = $sth->fetchrow_hashref();
    $sth->finish();

    return $row;
}

# 1件取得（password も内部判定用に取得する。JSON 返却時は Service / Entity 側で除外）
sub find_by_id_old {
    my ($self, $id) = @_;
    return undef unless defined $id && $id =~ /^\d+$/;

    my $fields='id, title, content, password, email, time_stamp created_at';

    my $sth = $self->{dbh}->prepare(q{
        SELECT id, title, content, password, email, time_stamp, created_at
        FROM posts
        WHERE id = ?
    });
    $sth->execute($id);
    my $row = $sth->fetchrow_hashref();
    $sth->finish();

    #return _row_to_entity($row);
    return $row;
}

# new 2026.11.22
# 検索＋ページング用一覧取得
sub find_paginated {
    my ($self, $page, $per_page, $q) = @_;
    $page     = (defined $page && $page =~ /^\d+$/ && $page > 0) ? int($page) : 1;
    $per_page = (defined $per_page && $per_page =~ /^\d+$/ && $per_page > 0) ? int($per_page) : 5;
    $q        = defined $q ? "$q" : '';

    my $where_sql = '';
    my @bind;
    if ($q ne '') {
        $where_sql = 'WHERE title LIKE ? OR content LIKE ? OR email LIKE ?';
        my $like = '%' . $q . '%';
        push @bind, $like, $like, $like;
    }

    my $count_sth = $self->{dbh}->prepare("SELECT COUNT(*) FROM posts $where_sql");
    $count_sth->execute(@bind);
    my ($total) = $count_sth->fetchrow_array();
    $count_sth->finish();
    $total //= 0;

    my $total_pages = $total > 0 ? int(($total + $per_page - 1) / $per_page) : 1;
    if ($page > $total_pages) {
        $page = $total_pages;
    }
    my $offset = ($page - 1) * $per_page;

    my $sth = $self->{dbh}->prepare(qq{
        SELECT id, yname, title, content, email, time_stamp, created_at
        FROM posts
        $where_sql
        ORDER BY id DESC
        LIMIT ? OFFSET ?
    });
    $sth->execute(@bind, $per_page, $offset);

    my @rows;
    while (my $row = $sth->fetchrow_hashref()) {
        push @rows, $row;
    }

    $sth->finish();

    return {
        posts        => \@rows,
        total        => int($total),
        total_pages  => int($total_pages),
        current_page => int($page),
        q            => $q,
    };
}

# ページネーション対応のデータ取得 (LIMIT / OFFSET)
sub find_paginated_old2 {
    my ($self, $limit, $offset, $keyword) = @_;
    my $sth;

    if (defined $keyword && $keyword ne '') {
        #my $like = '%' . $keyword . '%';
        my $like = $self->_escape_like($keyword);
        $sth = $self->{dbh}->prepare(
            "SELECT id, title, content, created_at FROM posts WHERE title LIKE ? OR content LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?"
        );
        $sth->execute($like, $like, $limit, $offset);
    }
    else {
        $sth = $self->{dbh}->prepare(
            "SELECT id, title, content, created_at FROM posts ORDER BY id DESC LIMIT ? OFFSET ?"
        );
        $sth->execute($limit, $offset);
    }
    
    my @posts;
    while (my $row = $sth->fetchrow_hashref) {
        push @posts, Blog::Entity::Post->new($row);
    }
    return \@posts;
}

# ページネーション対応のデータ取得 (LIMIT / OFFSET)
sub find_paginated_old {
    my ($self, $limit, $offset, $keyword) = @_;
    my $sth;

    if (defined $keyword && $keyword ne '') {
        #my $like = '%' . $keyword . '%';
        my $like = $self->_escape_like($keyword);
        $sth = $self->{dbh}->prepare(
            "SELECT id, title, content, created_at FROM posts WHERE title LIKE ? OR content LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?"
        );
        $sth->execute($like, $like, $limit, $offset);
    }
    else {
        $sth = $self->{dbh}->prepare(
            "SELECT id, title, content, created_at FROM posts ORDER BY id DESC LIMIT ? OFFSET ?"
        );
        $sth->execute($limit, $offset);
    }
    
    my @posts;
    while (my $row = $sth->fetchrow_hashref) {
        push @posts, Blog::Entity::Post->new($row);
    }
    return \@posts;
}

# new 2026.11.22
# 新規作成
sub create {
    my ($self, $data) = @_;
    $data ||= {};

    my $yname      = $data->{yname}      // '';
    my $title      = $data->{title}      // '';
    my $content    = $data->{content}    // '';
    my $password   = $data->{password}   // '';
    my $email      = $data->{email}      // '';
    my $time_stamp = defined $data->{time_stamp} ? int($data->{time_stamp}) : time();

    my $sth = $self->{dbh}->prepare(q{
        INSERT INTO posts (yname, title, content, password, email, time_stamp)
        VALUES (?, ?, ?, ?, ?, ?)
    });
    $sth->execute($yname, $title, $content, $password, $email, $time_stamp);
    $sth->finish();

    my $new_id = $self->{dbh}->last_insert_id(undef, undef, 'posts', 'id');
    return $self->find_by_id($new_id);
}

sub create_old {
    my ($self, $title, $content) = @_;
    my $sth = $self->{dbh}->prepare("INSERT INTO posts (title, content) VALUES (?, ?)");
    $sth->execute($title, $content);
    my $id = $self->{dbh}->last_insert_id("", "", "posts", "");
    
    # 登録されたレコードを返す
    my $row = $self->{dbh}->selectrow_hashref("SELECT id, title, content, created_at FROM posts WHERE id = ?", undef, $id);
    return Blog::Entity::Post->new($row);
}

# new 2026.11.22
# 更新（呼び出し元でパスワード照合済みを想定）
sub update {
    my ($self, $id, $data) = @_;
    return undef unless defined $id && $id =~ /^\d+$/;
    $data ||= {};

    my $current = $self->find_by_id($id);
    return undef unless $current;

    my $yname      = exists $data->{yname}   ? $data->{yname}   : $current->{yname};
    my $title      = exists $data->{title}   ? $data->{title}   : $current->{title};
    my $content    = exists $data->{content} ? $data->{content} : $current->{content};
    my $email      = exists $data->{email}   ? $data->{email}   : $current->{email};
    my $time_stamp = defined $data->{time_stamp} ? int($data->{time_stamp}) : time();

    # パスワード入力が指定された場合のみ上書き（未指定・空文字なら既存維持）
    my $password = $current->{password};
    if (exists $data->{password} && defined $data->{password} && $data->{password} ne '') {
        $password = $data->{password};
    }

    my $sth = $self->{dbh}->prepare(q{
        UPDATE posts
        SET yname = ?, title = ?, content = ?, password = ?, email = ?, time_stamp = ?
        WHERE id = ?
    });
    $sth->execute($yname, $title, $content, $password, $email, $time_stamp, $id);
    $sth->finish();

    return $self->find_by_id($id);
}

# new 2026.11.22
# 削除（呼び出し元でパスワード照合済みを想定）
sub delete {
    my ($self, $id) = @_;
    return 0 unless defined $id && $id =~ /^\d+$/;

    my $sth = $self->{dbh}->prepare('DELETE FROM posts WHERE id = ?');
    $sth->execute($id);
    my $deleted_rows = $sth->rows;
    $sth->finish();

    return ($deleted_rows && $deleted_rows > 0) ? 1 : 0;
}

#---- end 2026.11.22 の新規関数 ----

sub _row_to_entity {
    my ($row) = @_;
    return undef unless $row;
    return Blog::Entity::Post->new(
        id         => $row->{id},
        yname      => $row->{yname},
        title      => $row->{title},
        content    => $row->{content},
        password => $row->{password},
        email => $row->{email},
        time_stamp => $row->{time_stamp},
        created_at => $row->{created_at},
    );
}

sub count_posts {
    my ($self, $q) = @_;
    $q //= '';

    if ($q ne '') {
        my $like = '%' . $q . '%';
        my ($cnt) = $self->{dbh}->selectrow_array(
            'SELECT COUNT(*) FROM posts WHERE title LIKE ? OR content LIKE ?',
            undef,
            $like, $like
        );
        return 0 + ($cnt // 0);
    }
    else {
        my ($cnt) = $self->{dbh}->selectrow_array('SELECT COUNT(*) FROM posts');
        return 0 + ($cnt // 0);
    }
}


#---- 2 old ---
sub find_posts_paginated {
    my ($self, $limit, $offset, $q) = @_;
    $q //= '';
    my $fields='id, title, content, password, email, time_stamp created_at';
    my $sth;
    if ($q ne '') {
        my $like = '%' . $q . '%';
        $sth = $self->{dbh}->prepare(
            'SELECT '.$fields.' FROM posts '
          . 'WHERE title LIKE ? OR content LIKE ? '
          . 'ORDER BY id DESC LIMIT ? OFFSET ?'
        );
        $sth->execute($like, $like, $limit, $offset);
    }
    else {
        $sth = $self->{dbh}->prepare(
            'SELECT '.$fields.' FROM posts '
          . 'ORDER BY id DESC LIMIT ? OFFSET ?'
        );
        $sth->execute($limit, $offset);
    }

    my @posts;
    while (my $row = $sth->fetchrow_hashref()) {
        push @posts, _row_to_entity($row);
    }
    return \@posts;
}



sub insert_post {
    my ($self, $title, $content) = @_;
    $self->{dbh}->do(
        'INSERT INTO posts (title, content) VALUES (?, ?)',
        undef,
        $title, $content
    );
    my $id = $self->{dbh}->last_insert_id(undef, undef, 'posts', undef);
    return $self->find_by_id($id);
}

sub update_post {
    my ($self, $id, $title, $content) = @_;
    return undef unless defined $id && $id =~ /^\d+$/;

    my $sth = $self->{dbh}->prepare(
        'UPDATE posts SET title = ?, content = ? WHERE id = ?'
    );
    my $rows = $sth->execute($title, $content, $id);
    return undef unless defined $rows && $rows > 0;
    return $self->find_by_id($id);
}

sub delete_post {
    my ($self, $id) = @_;
    return 0 unless defined $id && $id =~ /^\d+$/;

    my $sth = $self->{dbh}->prepare('DELETE FROM posts WHERE id = ?');
    my $rows = $sth->execute($id);
    return (defined $rows && $rows > 0) ? 1 : 0;
}


#---- org start ----

# LIKE句用のワイルドカードエスケープ
sub _escape_like {
    my ($self, $str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/%/\\%/g;
    $str =~ s/_/\\_/g;
    return '%' . $str . '%';
}

sub find_all {
    my $self = shift;
    my $sth = $self->{dbh}->prepare("SELECT id, title, content, created_at FROM posts ORDER BY id DESC");
    $sth->execute();
    
    my @posts;
    while (my $row = $sth->fetchrow_hashref) {
        push @posts, Blog::Entity::Post->new($row);
    }
    return \@posts;
}

# データの総件数を取得（検索キーワード対応）
sub count_all {
    my ($self, $keyword) = @_;
    if (defined $keyword && $keyword ne '') {
        #my $like = '%' . $keyword . '%';
        my $like = $self->_escape_like($keyword);
        my ($count) = $self->{dbh}->selectrow_array(
            "SELECT COUNT(*) FROM posts WHERE title LIKE ? OR content LIKE ?",
            undef,
            $like,
            $like
        );
        return $count // 0;
    }

    my ($row) = $self->{dbh}->selectrow_array("SELECT COUNT(*) FROM posts");
    return $row // 0;
    #my $row = $self->{dbh}->selectrow_arrayref("SELECT COUNT(*) FROM posts");
    #return ($row && defined $row->[0]) ? $row->[0] : 0;
}




# 指定IDの記事を削除（削除された行数を返す）
sub delete_by_id {
    my ($self, $id) = @_;
    my $sth = $self->{dbh}->prepare("DELETE FROM posts WHERE id = ?");
    $sth->execute($id);
    return $sth->rows;
}

# 指定IDの記事を更新（更新後のEntityを返す。見つからない場合は undef）
sub update_by_id {
    my ($self, $id, $title, $content) = @_;
    my $sth = $self->{dbh}->prepare(
        "UPDATE posts SET title = ?, content = ? WHERE id = ?"
    );
    $sth->execute($title, $content, $id);
    return undef unless $sth->rows && $sth->rows > 0;

    my $row = $self->{dbh}->selectrow_hashref(
        "SELECT id, title, content, created_at FROM posts WHERE id = ?",
        undef,
        $id
    );
    return $row ? Blog::Entity::Post->new($row) : undef;
}

1;
