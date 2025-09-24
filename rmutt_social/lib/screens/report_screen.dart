import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';

class ReportScreen extends StatefulWidget {
  final String reportType; // 'post', 'comment', 'user'
  final String reportedId;
  final String? reportedUserId; // For posts and comments
  final Map<String, dynamic>? additionalData; // Extra context like post content, etc.

  const ReportScreen({
    super.key,
    required this.reportType,
    required this.reportedId,
    this.reportedUserId,
    this.additionalData,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedReason;
  final _additionalDetailsController = TextEditingController();
  bool _isSubmitting = false;

  final Map<String, List<String>> _reportReasons = {
    'post': [
      'Spam or misleading content',
      'Hate speech or harassment',
      'Violence or dangerous content',
      'Nudity or sexual content',
      'False information',
      'Intellectual property violation',
      'Suicide or self-harm',
      'Other',
    ],
    'comment': [
      'Spam or unwanted content',
      'Hate speech or harassment',
      'Bullying or intimidation',
      'False information',
      'Off-topic or irrelevant',
      'Inappropriate language',
      'Other',
    ],
    'user': [
      'Impersonation',
      'Harassment or bullying',
      'Spam account',
      'Hate speech',
      'Fake account',
      'Inappropriate profile content',
      'Underage user',
      'Other',
    ],
  };

  @override
  void dispose() {
    _additionalDetailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for reporting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      await firebaseService.createReport(
        reportType: widget.reportType,
        reportedId: widget.reportedId,
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason!,
        additionalDetails: _additionalDetailsController.text.trim(),
        additionalData: widget.additionalData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully. Thank you for helping keep our community safe.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildReportedContentPreview() {
    if (widget.additionalData == null) return const SizedBox.shrink();

    switch (widget.reportType) {
      case 'post':
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reported Post',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.additionalData!['content'] != null)
                  Text(
                    widget.additionalData!['content'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.additionalData!['imageUrl'] != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.additionalData!['imageUrl'],
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

      case 'comment':
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reported Comment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.additionalData!['content'] != null)
                  Text(
                    widget.additionalData!['content'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        );

      case 'user':
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reported User',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: widget.additionalData!['photoURL'] != null
                          ? CachedNetworkImageProvider(widget.additionalData!['photoURL'])
                          : null,
                      child: widget.additionalData!['photoURL'] == null
                          ? Text((widget.additionalData!['displayName'] ?? 'U')[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.additionalData!['displayName'] ?? 'Unknown User',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (widget.additionalData!['bio'] != null)
                            Text(
                              widget.additionalData!['bio'],
                              style: TextStyle(color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = _reportReasons[widget.reportType] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Report ${widget.reportType.capitalize()}'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting report...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Information header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.red.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.report, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Report Content',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Help us understand what\'s happening. Your report is confidential and helps keep our community safe.',
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ],
                    ),
                  ),

                  // Content preview
                  _buildReportedContentPreview(),

                  // Reason selection
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why are you reporting this ${widget.reportType}?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...reasons.map((reason) {
                          return RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                            groupValue: _selectedReason,
                            onChanged: (value) {
                              setState(() {
                                _selectedReason = value;
                              });
                            },
                            activeColor: Colors.red.shade700,
                          );
                        }),
                      ],
                    ),
                  ),

                  // Additional details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Details (Optional)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _additionalDetailsController,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            hintText: 'Provide any additional context that might help us understand your report...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Warning and guidelines
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Important Information',
                              style: TextStyle(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• False reports may result in action against your account\n'
                          '• We review all reports carefully\n'
                          '• You may not receive direct feedback on the outcome\n'
                          '• Reports are confidential and anonymous',
                          style: TextStyle(color: Colors.amber.shade800),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
      bottomNavigationBar: _isSubmitting
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedReason != null ? _submitReport : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Submit Report'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Report List Screen for moderators/admins
class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildReportsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.report_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No ${status.toLowerCase()} reports'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final report = snapshot.data!.docs[index];
            final reportData = report.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(reportData['status']),
                  child: Icon(
                    _getReportTypeIcon(reportData['reportType']),
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  '${reportData['reportType'].toString().capitalize()} Report',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason: ${reportData['reason']}'),
                    Text(
                      'Reported: ${_formatDate(reportData['createdAt'])}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleReportAction(report.id, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    if (reportData['status'] == 'pending') ...[
                      const PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Take Action'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'dismiss',
                        child: Row(
                          children: [
                            Icon(Icons.close, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Dismiss'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      case 'investigating':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getReportTypeIcon(String reportType) {
    switch (reportType) {
      case 'post':
        return Icons.post_add;
      case 'comment':
        return Icons.comment;
      case 'user':
        return Icons.person;
      default:
        return Icons.report;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return timestamp.toString();
  }

  void _handleReportAction(String reportId, String action) {
    // Implement report actions (view, approve, dismiss)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action action on report $reportId')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Reports'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Investigating'),
            Tab(text: 'Resolved'),
            Tab(text: 'Dismissed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsList('pending'),
          _buildReportsList('investigating'),
          _buildReportsList('resolved'),
          _buildReportsList('dismissed'),
        ],
      ),
    );
  }
}