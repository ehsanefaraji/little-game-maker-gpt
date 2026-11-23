import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original, resolution-independent illustrated world art used by the home screen.
class AdventureHero extends StatelessWidget {
  const AdventureHero({super.key, required this.onCreate, required this.projectCount});
  final VoidCallback onCreate;
  final int projectCount;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 218,
          child: Stack(fit: StackFit.expand, children: [
            const CustomPaint(painter: _AdventureLandscape()),
            Positioned(
              right: 20,
              top: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.22), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(.35))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15), SizedBox(width: 5), Text('استودیوی خلاقیت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))]),
              ),
            ),
            Positioned(
              right: 20,
              top: 62,
              left: 120,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('سلام، قهرمان کوچولو!', style: TextStyle(color: Colors.white, fontSize: 23, height: 1.25, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 2))])),
                const SizedBox(height: 7),
                const Text('دنیای خودت را بساز؛\nقهرمانت را انتخاب کن و ماجراجویی را شروع کن.', style: TextStyle(color: Color(0xFFF8F5FF), fontSize: 12, height: 1.55, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 17),
                  label: const Text('ساخت اولین بازی'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD66B), foregroundColor: const Color(0xFF49356E), elevation: 4, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ]),
            ),
            Positioned(left: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0x55362968), borderRadius: BorderRadius.circular(18)), child: Text('$projectCount بازی ساخته‌شده', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)))),
          ]),
        ),
      );
}

class _AdventureLandscape extends CustomPainter {
  const _AdventureLandscape();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4C79D8), Color(0xFF8E75D8), Color(0xFFE18DBA)]).createShader(rect));
    final sun = Offset(size.width * .19, size.height * .23);
    canvas.drawCircle(sun, 43, Paint()..color = const Color(0x44FFF1A8));
    canvas.drawCircle(sun, 28, Paint()..color = const Color(0xFFFFE69B));
    final cloudPaint = Paint()..color = const Color(0xDDFBFAFF);
    for (final p in [Offset(size.width*.55,size.height*.19), Offset(size.width*.82,size.height*.31)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:p,width:70,height:18),const Radius.circular(12)),cloudPaint);
      canvas.drawCircle(p.translate(-15,-5),12,cloudPaint); canvas.drawCircle(p.translate(1,-10),16,cloudPaint); canvas.drawCircle(p.translate(18,-4),12,cloudPaint);
    }
    _hill(canvas,size, .68, const Color(0xFF567DC6), .20);
    _hill(canvas,size, .77, const Color(0xFF4D9A91), .18);
    _hill(canvas,size, .88, const Color(0xFF367B68), .12);
    final ground = Path()..moveTo(0,size.height*.88)..quadraticBezierTo(size.width*.35,size.height*.76,size.width*.62,size.height*.88)..quadraticBezierTo(size.width*.83,size.height*.98,size.width,size.height*.83)..lineTo(size.width,size.height)..lineTo(0,size.height)..close();
    canvas.drawPath(ground, Paint()..color=const Color(0xFF34765C));
    // Small stylized trees add scale and a handcrafted storybook feeling.
    for (var i=0;i<7;i++) {
      final x=size.width*(.04+i*.14); final y=size.height*(.83+(i.isEven ? .015 : 0.0));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x-3,y-24,6,29),const Radius.circular(3)),Paint()..color=const Color(0xFF80533F));
      canvas.drawCircle(Offset(x,y-32),13,Paint()..color=i.isEven?const Color(0xFF71C77A):const Color(0xFF8BD889));
      canvas.drawCircle(Offset(x-6,y-36),6,Paint()..color=const Color(0xFFA9E99A));
    }
    _fox(canvas, Offset(size.width*.82,size.height*.73), math.min(size.height*.58,116.0));
    // Tiny sparkles.
    final sparkle=Paint()..color=const Color(0xFFFFF3B8);
    for(final p in [Offset(size.width*.42,size.height*.32),Offset(size.width*.68,size.height*.48),Offset(size.width*.94,size.height*.12)]) {
      canvas.drawCircle(p,2.2,sparkle); canvas.drawLine(p.translate(-5,0),p.translate(5,0),sparkle..strokeWidth=1.3); canvas.drawLine(p.translate(0,-5),p.translate(0,5),sparkle);
    }
  }
  void _hill(Canvas c,Size s,double y,Color color,double wave) { final p=Path()..moveTo(0,s.height*y)..cubicTo(s.width*.22,s.height*(y-wave),s.width*.34,s.height*(y+wave),s.width*.56,s.height*y)..cubicTo(s.width*.76,s.height*(y-wave*.7),s.width*.88,s.height*(y+wave),s.width,s.height*(y-.04))..lineTo(s.width,s.height)..lineTo(0,s.height)..close(); c.drawPath(p,Paint()..color=color); }
  void _fox(Canvas c,Offset center,double d) {
    c.drawOval(Rect.fromCenter(center:center.translate(0,d*.42),width:d*.72,height:d*.13),Paint()..color=const Color(0x330D2740));
    final tail=Path()..moveTo(center.dx+d*.18,center.dy+d*.22)..quadraticBezierTo(center.dx+d*.66,center.dy+d*.52,center.dx+d*.53,center.dy+d*.05)..quadraticBezierTo(center.dx+d*.46,center.dy-d*.12,center.dx+d*.31,center.dy+d*.02)..close();
    c.drawPath(tail,Paint()..color=const Color(0xFFE98545));
    c.drawCircle(center.translate(d*.49,d*.12),d*.12,Paint()..color=const Color(0xFFFFF1D8));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:center.translate(0,d*.19),width:d*.55,height:d*.48),Radius.circular(d*.19)),Paint()..color=const Color(0xFFE98545));
    final head=Path()..moveTo(center.dx-d*.25,center.dy-d*.04)..lineTo(center.dx-d*.28,center.dy-d*.48)..lineTo(center.dx-d*.04,center.dy-d*.32)..quadraticBezierTo(center.dx+d*.02,center.dy-d*.37,center.dx+d*.08,center.dy-d*.32)..lineTo(center.dx+d*.31,center.dy-d*.49)..lineTo(center.dx+d*.27,center.dy-d*.04)..quadraticBezierTo(center.dx,center.dy+d*.19,center.dx-d*.25,center.dy-d*.04)..close();
    c.drawPath(head,Paint()..color=const Color(0xFFF39A51));
    c.drawCircle(center.translate(-d*.14,-d*.1),d*.045,Paint()..color=Colors.white);
    c.drawCircle(center.translate(d*.14,-d*.1),d*.045,Paint()..color=Colors.white);
    c.drawCircle(center.translate(-d*.14,-d*.1),d*.021,Paint()..color=const Color(0xFF382B48));
    c.drawCircle(center.translate(d*.14,-d*.1),d*.021,Paint()..color=const Color(0xFF382B48));
    final muzzle=Paint()..color=const Color(0xFFFFE5C8); c.drawOval(Rect.fromCenter(center:center.translate(0,d*.015),width:d*.25,height:d*.15),muzzle); c.drawCircle(center.translate(0,d*.005),d*.027,Paint()..color=const Color(0xFF53364A));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:center.translate(-d*.13,d*.4),width:d*.16,height:d*.09),Radius.circular(d*.04)),Paint()..color=const Color(0xFFFFD56D));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:center.translate(d*.13,d*.4),width:d*.16,height:d*.09),Radius.circular(d*.04)),Paint()..color=const Color(0xFFFFD56D));
  }
  @override
  bool shouldRepaint(covariant _AdventureLandscape oldDelegate)=>false;
}
