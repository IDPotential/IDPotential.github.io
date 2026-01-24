import 'package:flutter/material.dart';
import '../data/diagnostic_data.dart';
import 'role_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LibraryScreen extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrev;
  const LibraryScreen({super.key, this.onMenuTap, this.onSwipeNext, this.onSwipePrev});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: onMenuTap != null 
             ? IconButton(icon: const Icon(Icons.menu), onPressed: onMenuTap)
             : null,
          title: const Text('Библиотека знаний'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Роли'),
              Tab(text: 'Аспекты'),
              Tab(text: 'Расшифровки'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: NotificationListener<OverscrollNotification>(
               onNotification: (notification) {
                 if (notification.overscroll < 0 && notification.metrics.pixels == notification.metrics.minScrollExtent) {
                    if (onSwipePrev != null) { onSwipePrev!(); return true; }
                 }
                 if (notification.overscroll > 0 && notification.metrics.pixels == notification.metrics.maxScrollExtent) {
                    if (onSwipeNext != null) { onSwipeNext!(); return true; }
                 }
                 return false;
               },
               child: TabBarView(
                children: [
                  _buildGrid(context, isAspects: false),
                  _buildGrid(context, isAspects: true),
                  _buildDecryptionsList(context),
                ],
               ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecryptionsList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: decryptionsInfo.length,
      itemBuilder: (context, index) {
        final item = decryptionsInfo[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(
              item['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(
              item['description'] ?? '',
              style: TextStyle(color: Colors.grey[600]),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...(item['details'] as List<String>).map((detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(detail)),
                        ],
                      ),
                    )),
                    if (item['url'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final url = Uri.parse(item['url']);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0), // Purple accent
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Заказать'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, {required bool isAspects}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 1, // Keep it square or adjust if text is long
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 22,
      itemBuilder: (context, index) {
        final number = index + 1;
        
        // Aspect Logic
        String displayTitle = '$number';
        String displaySubtitle = '';
        
        if (isAspects) {
            // Logic to find the key pair
            int partner = 22 - number;
            
            // Handle 22 case (maps to 0-0 or 22)
            if (number == 22) {
                displayTitle = '0-0'; 
                if (aspectsRole.containsKey('0-0')) {
                     displaySubtitle = aspectsRole['0-0']?['aspect_name'] ?? '';
                }
            } else {
                displayTitle = '$number-$partner';
                
                String key = '$number-$partner';
                if (aspectsRole.containsKey(key)) {
                    displaySubtitle = aspectsRole[key]?['aspect_name'] ?? '';
                } else {
                    String reverseKey = '$partner-$number';
                    if (aspectsRole.containsKey(reverseKey)) {
                        displaySubtitle = aspectsRole[reverseKey]?['aspect_name'] ?? '';
                    }
                }
            }
        } else {
            // Role Logic
            if (zones.containsKey(number)) {
                displaySubtitle = zones[number]?['role_name'] ?? zones[number]?['name'] ?? '';
            }
        }
        
        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoleDetailScreen(
                    number: number,
                    isAspect: isAspects,
                  ),
                ),
              );
            },
            child: Padding(
               padding: const EdgeInsets.all(8.0),
               child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      fontSize: 24, // Slightly smaller to fit "10-12"
                      fontWeight: FontWeight.bold,
                      fontFamily: 'DINPro',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displaySubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}