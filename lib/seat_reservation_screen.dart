import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SeatReservationScreen extends StatefulWidget {
  const SeatReservationScreen({super.key});

  @override
  State<SeatReservationScreen> createState() => _SeatReservationScreenState();
}

class _SeatReservationScreenState extends State<SeatReservationScreen> {
  int _reservedSeat = -1;
  List<int> _seatStatus = List.filled(12, 0); // 0: 사용 가능, 1: 사용 중, 2: 내가 예약

  final List<int> _prioritySeats = [0, 5];

  @override
  void initState() {
    super.initState();
    _loadSeatData();
  }

  Future<void> _loadSeatData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('subway_cars')
          .doc('line2_car1')
          .get();

      List<dynamic> data = doc['seats'];
      setState(() {
        _seatStatus = data.cast<int>();
      });
    } catch (e) {
      print('🚨 Firestore 데이터 불러오기 실패: $e');
    }
  }

  void _toggleSeatReservation(int seatIndex) {
    if (!_prioritySeats.contains(seatIndex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('임산부 배려석만 선택할 수 있습니다.')),
      );
      return;
    }

    if (_seatStatus[seatIndex] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 다른 사람이 사용 중인 좌석입니다.')),
      );
      return;
    }

    setState(() {
      if (_seatStatus[seatIndex] == 2) {
        _seatStatus[seatIndex] = 0;
        _reservedSeat = -1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${seatIndex + 1}번 좌석 예약을 취소했습니다.')),
        );
      } else {
        if (_reservedSeat != -1) {
          _seatStatus[_reservedSeat] = 0;
        }
        _seatStatus[seatIndex] = 2;
        _reservedSeat = seatIndex;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${seatIndex + 1}번 좌석을 예약했습니다.')),
        );
      }

      // Firestore 업데이트
      FirebaseFirestore.instance
          .collection('subway_cars')
          .doc('line2_car1')
          .update({'seats': _seatStatus});
    });
  }

  Widget _buildSeat(int index) {
    Color seatColor;
    IconData seatIcon = Icons.chair_rounded;
    bool isPriority = _prioritySeats.contains(index);

    if (_seatStatus[index] == 2) {
      seatColor = Colors.green;
    } else if (_seatStatus[index] == 1) {
      seatColor = Colors.grey[700]!;
    } else {
      seatColor = isPriority ? Colors.pink.shade200 : Colors.grey.shade400;
    }

    return GestureDetector(
      onTap: () => _toggleSeatReservation(index),
      child: Column(
        children: [
          Icon(seatIcon, color: seatColor, size: 40),
          Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (isPriority)
            const Text('임산부석', style: TextStyle(color: Colors.pink, fontSize: 10))
          else
            const SizedBox(height: 12), // 자리 확보용
        ],
      ),
    );
  }

  Widget _buildSeatRow(int startIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const Text('출입문', style: TextStyle(fontSize: 16)),
        ...List.generate(6, (i) => _buildSeat(startIndex + i)),
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
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSeatRow(0),
              const SizedBox(height: 50),
              _buildSeatRow(6),
            ],
          ),
        ),
      ),
    );
  }
}
