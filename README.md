# perl-vue-blog  

Ubuntu 24.04 perl + Vue3 で、Web app サンプル (Blog/Bbs) を作ってみた。  

##### 1. 開発環境の用意。  
i) 必要なパッケージのインストール（Ubuntu 24.04）  
$ sudo apt update  
$ sudo apt install -y sqlite3 libsqlite3-dev cpanminus build-essential nodejs npm  
  
ii) Mojolicious（Perl製Webフレームワーク）のインストール  
注) ユーザディレクトリへ、インストールする。  
~/perl5/ 下のディレクトリーを使う。  
  
$ cpanm Mojolicious  
  
\~/perl5 用の環境変数が未設定の場合は、\~/.bashrc に追記して反映します。  
$ echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"' >> ~/.bashrc  
$ source ~/.bashrc  
確認してみる。  
$ mojo version  

##### 2. git clone   
    $ git clone https://github.com/tosa-no-onchan/perl-vue-blog.git  
    $ cd perl-vue-blog/frontend  
    $ npm install  
    $ npm run build  

##### 3. run  
起動方法は、3 種類あります。  
backend/app.pl を Deamon として、実行しておいて、  
backend 処理として、perl-vue-blog/backend/app.pl を使うのを前提に、  
frontend を、  
$ npm run dev  
で起動する。--- 方法1  
$ npm run build  
を行った後、ブラウザーから、frontend/dist/index.html を表示して実行する。 --- 方法2  

Mojolicious Deamon も、 npm run dev も使わずに、  
Http Server(おんちゃんの C++ Light Server が、お勧め) を起動しておいて、  
$ npm run build で、作成された、frontend/dist/index.html を表示して、  
http://xxxxx/index.html で、App.vue の backend 処理として、cgi-bin/api/posts.cgi を使う方法。 --- 方法3  

1) Mojolicious Deamon で実行するばあい。
   
    i) backend の起動  
    $ cd perl-vue-blog/backend  
    $ perl app.pl daemon  
    
    ii) frontend の起動  
    そく、実行するなら、下記を行う。
    $ cd perl-vue-blog/frontend  
    $ npm run dev  
    注) frontend/src/App.vue を修正しておく。  
    const use_cgi = 0  

2) cgi として実行する場合。  
    
    i) Http Server の、doc-root(web_root) と、 cgi-root を指定する。  
    doc-root: /home/your-id/path-to/perl-vue-blog/frontend/dist  
    cgi-root: /home/your-id/path-to/perl-vue-blog/backend  
    
    ii) frontend/src/App.vue を修正しておく。  
    const use_cgi = 1  
    const base = 'http://192.168.1.170/cgi-bin/api/posts.cgi'  
    上記の ip address を自分の環境に合わせる。  
    $ cd perl-vue-blog/frontend  
    $ npm run build  
    
    iii) ブラウザーから、http://ip-to-server/index.html  
   

  

