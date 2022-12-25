import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemax/screens/news_webview.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:web_scraper/web_scraper.dart';
import '../provider/darktheme_provider.dart';
import 'common_widgets.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({
    Key? key,
  }) : super(key: key);

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController tabController;
  int selectedIndex = 0;

  @override
  void initState() {
    tabController = TabController(length: 5, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Provider.of<DarkthemeProvider>(context).darktheme;
    return Column(
      children: [
        Container(
          color: const Color(0xFFF57C00),
          width: double.infinity,
          child: TabBar(
            isScrollable: true,
            onTap: (value) {
              setState(() {
                selectedIndex = value;
              });
            },
            tabs: [
              Tab(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(FontAwesomeIcons.fire),
                  ),
                  Text(
                    'Top news',
                  ),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.movie_creation_rounded),
                  ),
                  Text(
                    'Movie news',
                  ),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.live_tv_rounded)),
                  Text(
                    'TV news',
                  ),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(FontAwesomeIcons.user)),
                  Text(
                    'Celebrity news',
                  ),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(FontAwesomeIcons.starOfLife)),
                  Text(
                    'Indie news',
                  ),
                ],
              )),
            ],
            indicatorColor: isDark ? Colors.white : Colors.black,
            indicatorWeight: 3,
            //isScrollable: true,
            labelStyle: const TextStyle(
              fontFamily: 'PoppinsSB',
              color: Colors.black,
              fontSize: 17,
            ),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'Poppins', color: Colors.black87),
            labelColor: Colors.black,
            controller: tabController,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: selectedIndex,
            // controller: tabController,
            children: const [
              NewsView(newsType: '/news/top'),
              NewsView(
                newsType: '/news/movie',
              ),
              NewsView(newsType: '/news/tv'),
              NewsView(
                newsType: '/news/celebrity',
              ),
              NewsView(newsType: '/news/indie')
            ],
          ),
        )
      ],
    );
    // return Container(
    //   child: Text('data'),
    // );
  }

  @override
  bool get wantKeepAlive => true;
}

class NewsView extends StatefulWidget {
  const NewsView({
    Key? key,
    required this.newsType,
  }) : super(key: key);
  final String newsType;

  @override
  State<NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView>
    with AutomaticKeepAliveClientMixin {
  final WebScraper? webScraper = WebScraper('https://imdb.com');
  List<Map<String, dynamic>>? articleNames;
  List<Map<String, dynamic>>? atricleImage;
  List<Map<String, dynamic>>? articleWebsite;

  final scrollController = ScrollController();
  @override
  void initState() {
    getNewsWithRetry();
    super.initState();
  }

  bool isLoading = false;
  bool requestFailed = false;

  Future<void> getNews() async {
    if (await webScraper!.loadWebPage(widget.newsType)) {
      setState(() {
        articleNames = webScraper!.getElement(
            'h2.news-article__title > a.tracked-offsite-link', ['href']);
        atricleImage =
            webScraper!.getElement('img.news-article__image', ['src']);
        articleWebsite = webScraper!.getElement(
            'ul.news-article__header-detail > li.ipl-inline-list__item > a.tracked-offsite-link',
            ['class']);
      });
    }
  }

  void checkLoad() {
    if (articleNames == null) {
      setState(() {
        requestFailed = true;
        articleNames = [];
        articleWebsite = [];
        atricleImage = [];
      });
    }
  }

  void getNewsWithRetry() async {
    getNews();
    await Future.delayed(const Duration(seconds: 15));
    checkLoad();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Provider.of<DarkthemeProvider>(context).darktheme;
    return articleNames == null
        ? newsShimmer(isDark, scrollController, isLoading)
        : requestFailed == true
            ? newsRetryWidget()
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ListView.builder(
                        itemBuilder: ((context, index) {
                          Map<String, dynamic> attributes =
                              atricleImage![index]['attributes'];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return NewsWebView(
                                    atricleUrl: articleNames![index]
                                        ['attributes']['href']);
                              }));
                              // launch(
                              //   articleNames![index]['attributes'][
                              //       'href'], /* mode: LaunchMode.inAppWebView,*/
                              // );
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: SizedBox(
                                          height: 150,
                                          width: 100,
                                          child: attributes['src'] == null
                                              ? Image.asset(
                                                  'assets/images/na_logo.png',
                                                  fit: BoxFit.cover,
                                                )
                                              : CachedNetworkImage(
                                                  fadeOutDuration:
                                                      const Duration(
                                                          milliseconds: 300),
                                                  fadeOutCurve: Curves.easeOut,
                                                  fadeInDuration:
                                                      const Duration(
                                                          milliseconds: 700),
                                                  fadeInCurve: Curves.easeIn,
                                                  imageUrl: attributes['src'],
                                                  imageBuilder: (context,
                                                          imageProvider) =>
                                                      Container(
                                                    decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                        image: imageProvider,
                                                        // fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  // placeholder: (context, url) =>
                                                  //     scrollingImageShimmer(isDark),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.asset(
                                                    'assets/images/na_logo.png',
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                        )),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                articleNames![index]['title'],
                                                style: const TextStyle(
                                                    fontFamily: 'PoppinsSB',
                                                    /* fontSize: 18*/
                                                    fontSize: 15),
                                              ),
                                              Text(articleWebsite![index]
                                                  ['title']),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    color: !isDark
                                        ? Colors.black54
                                        : Colors.white54,
                                    thickness: 1,
                                    endIndent: 20,
                                    indent: 10,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        itemCount: atricleImage!.length,
                      ),
                    ),
                  ),
                ],
              );
  }

  Widget newsRetryWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/network-signal.png',
              width: 60, height: 60),
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('Please connect to the Internet and try again',
                textAlign: TextAlign.center),
          ),
          TextButton(
              style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all(const Color(0x0DF57C00)),
                  maximumSize: MaterialStateProperty.all(const Size(200, 60)),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.0),
                          side: const BorderSide(color: Color(0xFFF57C00))))),
              onPressed: () async {
                setState(() {
                  requestFailed = false;
                  articleNames = null;
                  articleWebsite = null;
                  atricleImage = null;
                });
                getNewsWithRetry();
              },
              child: const Text('Retry')),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
