{
  addressable = {
    dependencies = ["public_suffix"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ypdmpdn20hxp5vwxz3zc04r5xcwqc25qszdlg41h8ghdqbllwmw";
      type = "gem";
    };
    version = "2.8.1";
  };
  akami = {
    dependencies = ["gyoku" "nokogiri"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "168y57kd9wshzqqk127w7lknd8lr0b9k50wazw4c92zshq3sw2jd";
      type = "gem";
    };
    version = "1.3.1";
  };
  ast = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04nc8x27hlzlrr5c2gn7mar4vdr0apw5xg22wp6m8dx3wqr04a0y";
      type = "gem";
    };
    version = "2.4.2";
  };
  builder = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "045wzckxpwcqzrjr353cxnyaxgf0qg22jh00dcx7z38cys5g1jlr";
      type = "gem";
    };
    version = "3.2.4";
  };
  byebug = {
    groups = ["debugger" "default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nx3yjf4xzdgb8jkmk2344081gqr22pgjqnmjg2q64mj5d6r9194";
      type = "gem";
    };
    version = "11.1.3";
  };
  coderay = {
    groups = ["debugger" "default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0jvxqxzply1lwp7ysn94zjhh57vc14mcshw1ygw14ib8lhc00lyw";
      type = "gem";
    };
    version = "1.1.3";
  };
  connection_pool = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nj4r58m5cpfdsijj6gjfs3yzcnxq2halagjk07wjcrgj6z8ayb7";
      type = "gem";
    };
    version = "2.3.0";
  };
  crack = {
    dependencies = ["rexml"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cr1kfpw3vkhysvkk3wg7c54m75kd68mbm9rs5azdjdq57xid13r";
      type = "gem";
    };
    version = "0.4.5";
  };
  diff-lcs = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rwvjahnp7cpmracd8x732rjgnilqv2sx7d1gfrysslc3h039fa9";
      type = "gem";
    };
    version = "1.5.0";
  };
  domain_name = {
    dependencies = ["unf"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0lcqjsmixjp52bnlgzh4lg9ppsk52x9hpwdjd53k8jnbah2602h0";
      type = "gem";
    };
    version = "0.5.20190701";
  };
  flexmock = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "07l5hlz57fxaksr34q7n933sr2v6gfsplaiv1z4fi2ql731nvamm";
      type = "gem";
    };
    version = "2.3.6";
  };
  gyoku = {
    dependencies = ["builder" "rexml"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1kd2q59xpm39hpvmmvyi6g3f1fr05xjbnxwkrdqz4xy7hirqi79q";
      type = "gem";
    };
    version = "1.4.0";
  };
  hashdiff = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nynpl0xbj0nphqx1qlmyggq58ms1phf5i03hk64wcc0a17x1m1c";
      type = "gem";
    };
    version = "1.0.1";
  };
  htmlentities = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nkklqsn8ir8wizzlakncfv42i32wc0w9hxp00hvdlgjr7376nhj";
      type = "gem";
    };
    version = "4.3.4";
  };
  http-cookie = {
    dependencies = ["domain_name"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "13rilvlv8kwbzqfb644qp6hrbsj82cbqmnzcvqip1p6vqx36sxbk";
      type = "gem";
    };
    version = "1.0.5";
  };
  httpi = {
    dependencies = ["rack" "socksify"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0v8ah9indflp0w6jdzkzgs72xiwbam5v1c58migj0dkavkrai45h";
      type = "gem";
    };
    version = "2.5.0";
  };
  json = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nalhin1gda4v8ybk6lq8f407cgfrj6qzn234yra4ipkmlbfmal6";
      type = "gem";
    };
    version = "2.6.3";
  };
  language_server-protocol = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14r3zp2q75lrzpy2nz7hbhzqp8nsykd5ffy18d34xr32722i2ifr";
      type = "gem";
    };
    version = "3.17.0.2";
  };
  mechanize = {
    dependencies = ["domain_name" "http-cookie" "mime-types" "net-http-digest_auth" "net-http-persistent" "nokogiri" "ntlm-http" "webrick" "webrobots"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vb7x0zzd2lv50kls6wpnnxxm3ckkfpx53dldd8hxzccr9vkdb9b";
      type = "gem";
    };
    version = "2.7.7";
  };
  method_source = {
    groups = ["debugger" "default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pnyh44qycnf9mzi1j6fywd5fkskv3x7nmsqrrws0rjn5dd4ayfp";
      type = "gem";
    };
    version = "1.0.0";
  };
  mime-types = {
    dependencies = ["mime-types-data"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ipw892jbksbxxcrlx9g5ljq60qx47pm24ywgfbyjskbcl78pkvb";
      type = "gem";
    };
    version = "3.4.1";
  };
  mime-types-data = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "003gd7mcay800k2q4pb2zn8lwwgci4bhi42v2jvlidm8ksx03i6q";
      type = "gem";
    };
    version = "3.2022.0105";
  };
  mini_portile2 = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1af4yarhbbx62f7qsmgg5fynrik0s36wjy3difkawy536xg343mp";
      type = "gem";
    };
    version = "2.8.1";
  };
  minitar = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "126mq86x67d1p63acrfka4zx0cx2r0vc93884jggxnrmmnzbxh13";
      type = "gem";
    };
    version = "0.9";
  };
  multi_json = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pb1g1y3dsiahavspyzkdy39j4q377009f6ix0bh1ag4nqw43l0z";
      type = "gem";
    };
    version = "1.15.0";
  };
  net-http-digest_auth = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nq859b0gh2vjhvl1qh1zrk09pc7p54r9i6nnn6sb06iv07db2jb";
      type = "gem";
    };
    version = "1.4.1";
  };
  net-http-persistent = {
    dependencies = ["connection_pool"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1yfypmfg1maf20yfd22zzng8k955iylz7iip0mgc9lazw36g8li7";
      type = "gem";
    };
    version = "4.0.1";
  };
  nokogiri = {
    dependencies = ["mini_portile2" "racc"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cam1455nmi3fzzpa9ixn2hsim10fbprmj62ajpd6d02mwdprwwn";
      type = "gem";
    };
    version = "1.13.9";
  };
  nori = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "066wc774a2zp4vrq3k7k8p0fhv30ymqmxma1jj7yg5735zls8agn";
      type = "gem";
    };
    version = "2.6.0";
  };
  ntlm-http = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0yx01ffrw87wya1syivqzf8hz02axk7jdpw6aw221xwvib767d36";
      type = "gem";
    };
    version = "0.1.1";
  };
  oddb2xml = {
    dependencies = ["htmlentities" "httpi" "mechanize" "minitar" "multi_json" "nokogiri" "optimist" "ox" "parslet" "rexml" "rubyXL" "rubyntlm" "rubyzip" "savon" "sax-machine" "spreadsheet" "standardrb" "webrick" "xml-simple"];
    groups = ["default"];
    platforms = [];
    source = {
      path = ./.;
      type = "path";
    };
    version = "2.7.9";
  };
  optimist = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vg2chy1cfmdj6c1gryl8zvjhhmb3plwgyh1jfnpq4fnfqv7asrk";
      type = "gem";
    };
    version = "3.0.1";
  };
  ox = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0kzwl7m6cp2dyncpm7cc8wvk9zsj1hd1pmbgxhjy85xr4sq1qf8a";
      type = "gem";
    };
    version = "2.14.12";
  };
  parallel = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "07vnk6bb54k4yc06xnwck7php50l09vvlw1ga8wdz0pia461zpzb";
      type = "gem";
    };
    version = "1.22.1";
  };
  parser = {
    dependencies = ["ast"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0zk8mdyr0322r11d63rcp5jhz4lakxilhvyvdv0ql5dw4lb83623";
      type = "gem";
    };
    version = "3.2.0.0";
  };
  parslet = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01pnw6ymz6nynklqvqxs4bcai25kcvnd5x4id9z3vd1rbmlk0lfl";
      type = "gem";
    };
    version = "2.0.0";
  };
  pry = {
    dependencies = ["coderay" "method_source"];
    groups = ["debugger" "default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0k9kqkd9nps1w1r1rb7wjr31hqzkka2bhi8b518x78dcxppm9zn4";
      type = "gem";
    };
    version = "0.14.2";
  };
  pry-byebug = {
    dependencies = ["byebug" "pry"];
    groups = ["debugger"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1y41al94ks07166qbp2200yzyr5y60hm7xaiw4lxpgsm4b1pbyf8";
      type = "gem";
    };
    version = "3.10.1";
  };
  pry-doc = {
    dependencies = ["pry" "yard"];
    groups = ["debugger"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pp43n69p6bjvc640wgcz295w1q2v9awcqgbwcqn082dbvq5xvnx";
      type = "gem";
    };
    version = "1.4.0";
  };
  psych = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "186i2hc6sfvg4skhqf82kxaf4mb60g65fsif8w8vg1hc9mbyiaph";
      type = "gem";
    };
    version = "3.3.4";
  };
  public_suffix = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0hz0bx2qs2pwb0bwazzsah03ilpf3aai8b7lk7s35jsfzwbkjq35";
      type = "gem";
    };
    version = "5.0.1";
  };
  racc = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "09jgz6r0f7v84a7jz9an85q8vvmp743dqcsdm3z9c8rqcqv6pljq";
      type = "gem";
    };
    version = "1.6.2";
  };
  rack = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "006km9h9kfdipwpqvjkfb0hfnd65w60cw0imx6qmx77b0h746frs";
      type = "gem";
    };
    version = "3.0.3";
  };
  rainbow = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0smwg4mii0fm38pyb5fddbmrdpifwv22zv3d3px2xx497am93503";
      type = "gem";
    };
    version = "3.1.1";
  };
  rake = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15whn7p9nrkxangbs9hh75q585yfn66lv0v2mhj6q6dl6x8bzr2w";
      type = "gem";
    };
    version = "13.0.6";
  };
  rdoc = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0da6sydj5ls91d38cqdv4r18a4b68185cgbi4i7pjng2fq6h3msv";
      type = "gem";
    };
    version = "6.3.3";
  };
  regexp_parser = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rj7xcg7bkfw6y0h4wg8y3s4nmks9qrzdxag4zaw41xjqfanlysf";
      type = "gem";
    };
    version = "2.6.1";
  };
  rexml = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "08ximcyfjy94pm1rhcx04ny1vx2sk0x4y185gzn86yfsbzwkng53";
      type = "gem";
    };
    version = "3.2.5";
  };
  rspec = {
    dependencies = ["rspec-core" "rspec-expectations" "rspec-mocks"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "171rc90vcgjl8p1bdrqa92ymrj8a87qf6w20x05xq29mljcigi6c";
      type = "gem";
    };
    version = "3.12.0";
  };
  rspec-core = {
    dependencies = ["rspec-support"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ibb81slc35q5yp276sixp3yrvj9q92wlmi1glbnwlk6g49z8rn4";
      type = "gem";
    };
    version = "3.12.0";
  };
  rspec-expectations = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "03ba3lfdsj9zl00v1yvwgcx87lbadf87livlfa5kgqssn9qdnll6";
      type = "gem";
    };
    version = "3.12.2";
  };
  rspec-mocks = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0k64i7ax6sqvh702s0xrll2g8isxx1x4zam95ck7122flsyh7van";
      type = "gem";
    };
    version = "3.12.2";
  };
  rspec-support = {
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "12y52zwwb3xr7h91dy9k3ndmyyhr3mjcayk0nnarnrzz8yr48kfx";
      type = "gem";
    };
    version = "3.12.0";
  };
  rubocop = {
    dependencies = ["json" "parallel" "parser" "rainbow" "regexp_parser" "rexml" "rubocop-ast" "ruby-progressbar" "unicode-display_width"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0shbma3bjm761waklzg10gy9jxl6m48l5035kli429sw7qna5sm8";
      type = "gem";
    };
    version = "1.42.0";
  };
  rubocop-ast = {
    dependencies = ["parser"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pdzabz95hv3z5sfbkfqa8bdybsfl13gv7rjb32v3ss8klq99lbd";
      type = "gem";
    };
    version = "1.24.1";
  };
  rubocop-performance = {
    dependencies = ["rubocop" "rubocop-ast"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1iwv2zhcpaan038d6m7ybzb2dgpi2zhf9dgfs3bjvmrqirqi2720";
      type = "gem";
    };
    version = "1.15.2";
  };
  ruby-ole = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0zhaq66csdingjw34acnq3j56s0s1vhxvb1cnglw9vca958g0rvx";
      type = "gem";
    };
    version = "1.2.12.2";
  };
  ruby-progressbar = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "02nmaw7yx9kl7rbaan5pl8x5nn0y4j5954mzrkzi9i3dhsrps4nc";
      type = "gem";
    };
    version = "1.11.0";
  };
  rubyntlm = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "082649ph6d8vjkq31sg5rm6m03ffakjimjwxxydndbbk81fxq50q";
      type = "gem";
    };
    version = "0.5.1";
  };
  rubyXL = {
    dependencies = ["nokogiri" "rubyzip"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "147ld9pv819w6dz9x5994fw4arjd7pwj57g00wbjf1gy5mk1n6jg";
      type = "gem";
    };
    version = "3.4.25";
  };
  rubyzip = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0grps9197qyxakbpw02pda59v45lfgbgiyw48i0mq9f2bn9y6mrz";
      type = "gem";
    };
    version = "2.3.2";
  };
  savon = {
    dependencies = ["akami" "builder" "gyoku" "httpi" "nokogiri" "nori" "wasabi"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "19ry5ww84bv31k5617p5k7qpdyar4fqjxhvk54vfgcwkg7nlan2h";
      type = "gem";
    };
    version = "2.12.1";
  };
  sax-machine = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0fhdflwdj8q0gfgz51k3zn1giq24fwvhvji75104rsly0dw2c4d1";
      type = "gem";
    };
    version = "1.3.2";
  };
  socksify = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fp4p8p4y713lh00rd31xymxnzkbhmg0d12ixbqs7lcaj2pcgcni";
      type = "gem";
    };
    version = "1.7.1";
  };
  spreadsheet = {
    dependencies = ["ruby-ole"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1dlhfp69wk0ryffia8cw9ygzq73m7b21g046cma208k422bxfg79";
      type = "gem";
    };
    version = "1.3.0";
  };
  standard = {
    dependencies = ["language_server-protocol" "rubocop" "rubocop-performance"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1xwsmpkyxfz2bgcv1n8w3fdmxl19mwr5m512h723w30gcba5lpl8";
      type = "gem";
    };
    version = "1.21.1";
  };
  standardrb = {
    dependencies = ["standard"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0b0z6pipiajdday01zsr98b817jhyd328zimgslrfklz8az2h4vs";
      type = "gem";
    };
    version = "1.0.1";
  };
  timecop = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dlx4gx0zh836i7nzna03xdl7fc233s5z6plnr6k3kw46ah8d1fc";
      type = "gem";
    };
    version = "0.9.6";
  };
  unf = {
    dependencies = ["unf_ext"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bh2cf73i2ffh4fcpdn9ir4mhq8zi50ik0zqa1braahzadx536a9";
      type = "gem";
    };
    version = "0.1.4";
  };
  unf_ext = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1yj2nz2l101vr1x9w2k83a0fag1xgnmjwp8w8rw4ik2rwcz65fch";
      type = "gem";
    };
    version = "0.0.8.2";
  };
  unicode-display_width = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1gi82k102q7bkmfi7ggn9ciypn897ylln1jk9q67kjhr39fj043a";
      type = "gem";
    };
    version = "2.4.2";
  };
  vcr = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1xzd8f17mmcq9f6lxg4w0x4nd9pyp41lr77gjzxwynijzp8rcgjl";
      type = "gem";
    };
    version = "6.1.0";
  };
  wasabi = {
    dependencies = ["addressable" "httpi" "nokogiri"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1mffdf7z1rmcs0k678vhzgnb080zcwhkk94hvj3hxjakys339ndb";
      type = "gem";
    };
    version = "3.7.0";
  };
  webmock = {
    dependencies = ["addressable" "crack" "hashdiff"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1myj44wvbbqvv18ragv3ihl0h61acgnfwrnj3lccdgp49bgmbjal";
      type = "gem";
    };
    version = "3.18.1";
  };
  webrick = {
    groups = ["debugger" "default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1d4cvgmxhfczxiq5fr534lmizkhigd15bsx5719r5ds7k7ivisc7";
      type = "gem";
    };
    version = "1.7.0";
  };
  webrobots = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "19ndcbba8s8m62hhxxfwn83nax34rg2k5x066awa23wknhnamg7b";
      type = "gem";
    };
    version = "0.1.2";
  };
  xml-simple = {
    dependencies = ["rexml"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pb9plyl71mdbjr4kllfy53qx6g68ryxblmnq9dilvy837jk24fj";
      type = "gem";
    };
    version = "1.1.9";
  };
  yard = {
    dependencies = ["webrick"];
    groups = ["debugger" "default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0p1if8g9ww6hlpfkphqv3y1z0rbqnnrvb38c5qhnala0f8qpw6yk";
      type = "gem";
    };
    version = "0.9.28";
  };
}
