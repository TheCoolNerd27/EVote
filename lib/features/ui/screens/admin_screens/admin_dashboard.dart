import 'package:e_vote/features/ui/bloc/admin_bloc/admin_bloc.dart';
import 'package:e_vote/features/ui/screens/admin_screens/add_candidate.dart';
import 'package:e_vote/features/ui/screens/admin_screens/add_voter.dart';
import 'package:e_vote/features/ui/screens/admin_screens/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_icons/flutter_icons.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  PageController pageController;
  TabController tabController;
  @override
  void initState() {
    pageController = PageController(initialPage: 1);
    tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminBloc>(
      create: (_) => AdminBloc(),
      child: Scaffold(
          body: PageView(
            allowImplicitScrolling: true,
            onPageChanged: (index) {
              tabController.index = index;
            },
            controller: pageController,
            children: <Widget>[
              AddCandidateScreen(),
              DashboardScreen(),
              AddVoterScreen()
            ],
          ),
          bottomNavigationBar: TabBar(
              labelColor: Color(0xff373737),
              indicatorColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Color(0xCC8e8e8e),
              controller: tabController,
              onTap: (index) {
                pageController.jumpToPage(index);
              },
              tabs: [
                Tab(icon: Icon(MaterialIcons.person_add)),
                Tab(icon: Icon(MaterialCommunityIcons.view_dashboard)),
                Tab(icon: Icon(FlutterIcons.vote_mco)),
              ])),
    );
  }
}
