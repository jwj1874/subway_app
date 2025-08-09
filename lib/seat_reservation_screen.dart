import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SeatReservationScreen extends StatefulWidget {
  const SeatReservationScreen({super.key});

  @override
  State<SeatReservationScreen> createState() => _SeatReservationScreenState();
}

class _SeatReservationScreenState extends State<SeatReservationScreen> {
  final _db = FirebaseFirestore.instance;
  User? get _me => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _seedSeatsIfEmpty(); // ✅ 최초 1회만 데이터 생성. 생성 후 주석 처리 가능.
  }

  Future<void> _seedSeatsIfEmpty() async {
    final col = _db.collection('seats');
    final snap = await col.get();
    if (snap.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (int i = 1; i <= 12; i++) {
      final ref = col.doc();
      batch.set(ref, {
        'seatNumber': i,
        'isPriority': (i == 1 || i == 6), // 1번, 6번 임산부석
        'reserved': false,
        'reservedBy': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _toggleSeat(DocumentSnapshot seatDoc) async {
    final myUid = _me!.uid;
    final ref = seatDoc.reference;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final d = snap.data() as Map<String, dynamic>;

        if (d['isPriority'] != true) {
          throw Exception('임산부 배려석만 선택할 수 있습니다.');
        }

        final reserved = d['reserved'] == true;
        final reservedBy = d['reservedBy'];

        if (!reserved) {
          tx.update(ref, {
            'reserved': true,
            'reservedBy': myUid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (reservedBy == myUid) {
          tx.update(ref, {
            'reserved': false,
            'reservedBy': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          throw Exception('이미 다른 사용자가 예약했습니다.');
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Color _seatColor(Map<String, dynamic> d, String? myUid) {
    final reserved = d['reserved'] == true;
    final reservedBy = d['reservedBy'];
    final isPriority = d['isPriority'] == true;

    if (reserved && reservedBy == myUid) return Colors.green;          // 내가 예약
    if (reserved) return Colors.grey[700]!;                            // 남이 예약
    return isPriority ? Colors.pink.shade200 : Colors.grey.shade400;   // 빈 좌석
  }

  Widget _seatTile(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final seatNumber = d['seatNumber'] ?? 0;
    final isPriority = d['isPriority'] == true;
    final color = _seatColor(d, _me?.uid);

    return GestureDetector(
      onTap: () => _toggleSeat(doc),
      child: Column(
        children: [
          Icon(Icons.chair_rounded, color: color, size: 40),
          Text('$seatNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (isPriority)
            const Text('임산부석', style: TextStyle(color: Colors.pink, fontSize: 10))
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _rowWithDoors(List<DocumentSnapshot> docs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const Text('출입문', style: TextStyle(fontSize: 16)),
        ...docs.map(_seatTile),
        const Text('출입문', style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('임산부 배려석 예약'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout), tooltip: '로그아웃'),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('seats').orderBy('seatNumber').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.length < 12) {
            return Center(
              child: Text('좌석 데이터가 부족합니다. (현재 ${docs.length}/12)\n처음 실행 시 자동 생성됩니다.'),
            );
          }

          final row1 = docs.take(6).toList();
          final row2 = docs.skip(6).take(6).toList();

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _rowWithDoors(row1),
                  const SizedBox(height: 50),
                  _rowWithDoors(row2),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
