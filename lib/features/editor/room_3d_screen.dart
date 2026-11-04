import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/language_controller.dart';
import '../../core/l10n/view3d_strings.dart';
import '../../core/theme/app_theme.dart';
import 'furniture_item.dart';
import 'furniture_material.dart';
import 'model3d.dart';
import 'room_geometry.dart';
import 'room_project_draft.dart';
import 'room_surface.dart';

// ----------------------------------------------------------------------
// Matematika 3D minimal. Sumbu: X ke kanan, Y ke atas, Z = sumbu Y denah.
// ----------------------------------------------------------------------

class _V3 {
  const _V3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _V3 operator +(_V3 o) => _V3(x + o.x, y + o.y, z + o.z);
  _V3 operator -(_V3 o) => _V3(x - o.x, y - o.y, z - o.z);
  _V3 operator *(double k) => _V3(x * k, y * k, z * k);

  double dot(_V3 o) => x * o.x + y * o.y + z * o.z;

  _V3 cross(_V3 o) =>
      _V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(dot(this));

  _V3 get unit {
    final l = length;
    return l < 1e-12 ? this : this * (1 / l);
  }
}

class _Face {
  const _Face(this.points, this.normal, this.color);

  final List<_V3> points;
  final _V3 normal;
  final Color color;

  _V3 get center {
    var sum = const _V3(0, 0, 0);

    for (final p in points) {
      sum = sum + p;
    }

    return sum * (1 / points.length);
  }
}

class _ItemModel {
  const _ItemModel(
    this.faces,
    this.center, {
    this.hostNormal,
    this.hostPoint,
    this.isMesh = false,
    this.faceCenters = const [],
  });

  /// Sisi samping lebih dulu, bidang atas terakhir.
  final List<_Face> faces;
  final _V3 center;

  /// Hanya untuk objek dinding: normal sisi dalam dinding penampungnya dan
  /// satu titik di dinding itu. Dipakai agar objek ikut tersembunyi bersama
  /// dindingnya ketika dinding membelakangi kamera.
  final _V3? hostNormal;
  final _V3? hostPoint;

  /// Model impor: semua segitiga diurutkan jauh ke dekat dan digambar dua sisi.
  final bool isMesh;

  /// Titik tengah tiap segitiga, dihitung sekali agar pengurutan cepat.
  final List<_V3> faceCenters;
}

double _signedArea(List<Offset> pts) {
  var sum = 0.0;

  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }

  return sum / 2;
}

/// Mengekstrusi poligon denah menjadi bidang-bidang 3D. Normal sisi samping
/// dihitung eksplisit agar pembuangan bidang belakang akurat.
List<_Face> _prism(
  List<Offset> plan,
  double baseY,
  double height,
  Color color, {
  bool outward = true,
  bool top = true,
}) {
  final area = _signedArea(plan);
  final faces = <_Face>[];
  final n = plan.length;

  for (var i = 0; i < n; i++) {
    final a = plan[i];
    final b = plan[(i + 1) % n];

    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);

    if (len < 1e-6) continue;

    // Untuk luas positif, bagian dalam ada di sisi (-dy, dx); luar = (dy, -dx).
    var nx = dy / len;
    var nz = -dx / len;

    if (area < 0) {
      nx = -nx;
      nz = -nz;
    }

    if (!outward) {
      nx = -nx;
      nz = -nz;
    }

    faces.add(
      _Face(
        [
          _V3(a.dx, baseY, a.dy),
          _V3(b.dx, baseY, b.dy),
          _V3(b.dx, baseY + height, b.dy),
          _V3(a.dx, baseY + height, a.dy),
        ],
        _V3(nx, 0, nz),
        color,
      ),
    );
  }

  if (top) {
    faces.add(
      _Face(
        [for (final p in plan) _V3(p.dx, baseY + height, p.dy)],
        const _V3(0, 1, 0),
        color,
      ),
    );
  }

  return faces;
}

/// Titik denah sebuah furnitur setelah rotasi dan posisi (cm).
List<Offset> _itemPlan(FurnitureItem item) {
  return [
    for (final p in item.localPoints)
      Offset(
        item.xCm + (item.isRotated ? item.lengthCm - p.y : p.x),
        item.yCm + (item.isRotated ? p.x : p.y),
      ),
  ];
}

/// Model 3D impor. Koordinat 0..1 dipetakan ke lebar, tinggi, dan
/// kedalaman furnitur, mengikuti rotasi dan posisinya di denah.
_ItemModel _meshModel(FurnitureItem item, FurnitureModel model) {
  final w = item.widthCm;
  final l = item.lengthCm;
  final h = item.effectiveHeightCm;

  _V3 map(double nx, double ny, double nz) {
    final lx = nx * w;
    final lz = nz * l;

    final px = item.isRotated ? item.xCm + l - lz : item.xCm + lx;
    final pz = item.isRotated ? item.yCm + lx : item.yCm + lz;

    return _V3(px, ny * h, pz);
  }

  final faces = <_Face>[];
  final centers = <_V3>[];

  for (final part in model.parts) {
    final v = part.vertices;
    final t = part.triangles;
    final color = part.colorValue != null
        ? Color(part.colorValue!)
        : item.material.color;

    final pts = <_V3>[
      for (var i = 0; i + 2 < v.length; i += 3) map(v[i], v[i + 1], v[i + 2]),
    ];

    for (var i = 0; i + 2 < t.length; i += 3) {
      final a = pts[t[i]];
      final b = pts[t[i + 1]];
      final c = pts[t[i + 2]];

      final n = (b - a).cross(c - a);

      if (n.length < 1e-9) continue;

      final face = _Face([a, b, c], n.unit, color);

      faces.add(face);
      centers.add(face.center);
    }
  }

  return _ItemModel(
    faces,
    _V3(
      item.xCm + item.effectiveWidthCm / 2,
      h / 2,
      item.yCm + item.effectiveLengthCm / 2,
    ),
    isMesh: true,
    faceCenters: centers,
  );
}
/// Kotak yang menempel di dinding. [start] titik kiri dinding (dilihat dari
/// dalam ruangan), [dir] arah ke kanan, [n] normal ke dalam ruangan.
_ItemModel _wallBox(
  _V3 start,
  _V3 dir,
  _V3 n,
  double x0,
  double x1,
  double yb,
  double yt,
  double depth,
  Color color,
) {
  // Sedikit menjauh dari dinding agar tidak berebut bidang dengannya.
  final base = start + n * 0.3;
  final a = base + dir * x0;
  final b = base + dir * x1;

  _V3 v(_V3 p, double d, double y) => _V3(p.x + n.x * d, y, p.z + n.z * d);

  final faces = <_Face>[
    _Face(
      [v(a, depth, yb), v(b, depth, yb), v(b, depth, yt), v(a, depth, yt)],
      n,
      color,
    ),
    _Face(
      [v(a, 0, yb), v(a, depth, yb), v(a, depth, yt), v(a, 0, yt)],
      dir * -1,
      color,
    ),
    _Face(
      [v(b, 0, yb), v(b, depth, yb), v(b, depth, yt), v(b, 0, yt)],
      dir,
      color,
    ),
    _Face(
      [v(a, 0, yb), v(b, 0, yb), v(b, depth, yb), v(a, depth, yb)],
      const _V3(0, -1, 0),
      color,
    ),
    _Face(
      [v(a, 0, yt), v(b, 0, yt), v(b, depth, yt), v(a, depth, yt)],
      const _V3(0, 1, 0),
      color,
    ),
  ];

  final mid = (a + b) * 0.5;

  return _ItemModel(
    faces,
    _V3(mid.x + n.x * depth / 2, (yb + yt) / 2, mid.z + n.z * depth / 2),
    hostNormal: n,
    hostPoint: start,
  );
}

/// Objek pada dinding yang terhubung ke sisi lurus denah.
List<_ItemModel> _wallItemModels(RoomProjectDraft project, List<Offset> plan) {
  final path = project.currentPath;
  final area = _signedArea(plan);
  final models = <_ItemModel>[];

  for (final surface in project.surfaces) {
    final i = surface.edgeIndex;

    if (surface.kind != SurfaceKind.wall || i < 0 || i >= path.length) {
      continue;
    }

    if (path.arcOf(i) != null) continue;

    final a = path.p(i);
    final b = path.p(i + 1);
    final len = (b - a).distance;

    if (len < 1) continue;

    final u = (b - a) / len;

    // Normal ke dalam ruangan pada denah.
    var nPlan = Offset(-u.dy, u.dx);

    if (area < 0) nPlan = -nPlan;

    // Arah "kanan" bagi orang yang berdiri di dalam menghadap dinding.
    final right = Offset(nPlan.dy, -nPlan.dx);
    final forward = right.dx * u.dx + right.dy * u.dy > 0;

    final startPlan = forward ? a : b;
    final dirPlan = forward ? u : -u;

    final start = _V3(startPlan.dx, 0, startPlan.dy);
    final dir = _V3(dirPlan.dx, 0, dirPlan.dy);
    final n = _V3(nPlan.dx, 0, nPlan.dy);

    for (final item in surface.items) {
      final x0 = item.xCm;

      if (x0 >= len) continue;

      final x1 = math.min(item.rightCm, len);

      if (x1 - x0 < 0.5) continue;

      final yb = math.max(
        0.0,
        surface.heightCm - (item.yCm + item.effectiveLengthCm),
      );
      final yt = yb + item.effectiveLengthCm;

      double depth;
      Color color;

      if (item.openingKind == 'window') {
        depth = 2;
        color = const Color(0xFFBFD9E6);
      } else if (item.openingKind == 'door') {
        depth = 2;
        color = item.material.color;
      } else {
        depth = item.heightCm > 0 ? item.heightCm.clamp(1.0, 100.0) : 5.0;
        color = item.material.color;
      }

      models.add(_wallBox(start, dir, n, x0, x1, yb, yt, depth, color));
    }
  }

  return models;
}

class _Scene {
  const _Scene({
    required this.floor,
    required this.walls,
    required this.items,
    required this.wallItems,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final List<Offset> floor;
  final List<_Face> walls;
  final List<_ItemModel> items;
  final List<_ItemModel> wallItems;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  static _Scene build(
    RoomProjectDraft project,
    List<RoomPoint> room,
    List<FurnitureItem> furniture,
    double wallHeight,
  ) {
    final plan = [for (final p in room) Offset(p.x, p.y)];

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final p in plan) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    final walls = _prism(
      plan,
      0,
      wallHeight,
      const Color(0xFFF1ECE0),
      outward: false,
      top: false,
    );

    final items = <_ItemModel>[];

    for (final item in furniture) {
      final model = item.model;

      if (model != null && model.triangleCount > 0) {
        items.add(_meshModel(item, model));
        continue;
      }

      final h = item.effectiveHeightCm;

      items.add(
        _ItemModel(
          _prism(_itemPlan(item), 0, h, item.material.color),
          _V3(
            item.xCm + item.effectiveWidthCm / 2,
            h / 2,
            item.yCm + item.effectiveLengthCm / 2,
          ),
        ),
      );
    }

    return _Scene(
      floor: plan,
      walls: walls,
      items: items,
      wallItems: _wallItemModels(project, plan),
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }
}

class _Camera {
  _Camera._(
    this.pos,
    this.forward,
    this.right,
    this.up,
    this.focal,
    this.center,
  );

  factory _Camera(
    _V3 target,
    double yaw,
    double pitch,
    double distance,
    Size size,
  ) {
    final pos =
        target +
        _V3(
              math.cos(pitch) * math.sin(yaw),
              math.sin(pitch),
              math.cos(pitch) * math.cos(yaw),
            ) *
            distance;

    final forward = (target - pos).unit;
    final right = forward.cross(const _V3(0, 1, 0)).unit;
    final up = right.cross(forward);

    return _Camera._(
      pos,
      forward,
      right,
      up,
      size.shortestSide * 1.1,
      Offset(size.width / 2, size.height / 2),
    );
  }

  final _V3 pos;
  final _V3 forward;
  final _V3 right;
  final _V3 up;
  final double focal;
  final Offset center;

  /// Null jika titik berada di belakang kamera.
  Offset? project(_V3 p) {
    final rel = p - pos;
    final zc = rel.dot(forward);

    if (zc < 5) return null;

    return Offset(
      center.dx + rel.dot(right) / zc * focal,
      center.dy - rel.dot(up) / zc * focal,
    );
  }
}

// ----------------------------------------------------------------------
// Layar
// ----------------------------------------------------------------------

/// Tampilan 3D ruangan dan furniturnya. Putar dengan menarik, zoom dengan
/// mencubit atau scroll, ketuk dua kali untuk mengembalikan sudut pandang.
/// Dinding yang dihubungkan ke sisi denah menampilkan objek, pintu, dan
/// jendelanya.
class Room3DScreen extends StatefulWidget {
  const Room3DScreen({super.key, required this.project, required this.items});

  final RoomProjectDraft project;

  /// Furnitur terkini di editor (bisa lebih baru daripada yang tersimpan).
  final List<FurnitureItem> items;

  @override
  State<Room3DScreen> createState() => _Room3DScreenState();
}

class _Room3DScreenState extends State<Room3DScreen> {
  static const double _defaultYaw = 0.6;
  static const double _defaultPitch = 0.62;

  double _yaw = _defaultYaw;
  double _pitch = _defaultPitch;
  late double _distance;
  double _startDistance = 1;

  bool _showWalls = true;
  double _wallHeight = 250;

  late final List<RoomPoint> _roomPoints;
  late _Scene _scene;

  double get _diag {
    final w = widget.project.widthCm;
    final l = widget.project.lengthCm;

    return math.sqrt(w * w + l * l);
  }

  double get _minDistance => 80;
  double get _maxDistance => math.max(400, _diag * 6);
  double get _defaultDistance => math.max(300, _diag * 1.5);

  @override
  void initState() {
    super.initState();

    _roomPoints = widget.project.effectiveRoomPoints;
    _distance = _defaultDistance;
    _scene = _Scene.build(
      widget.project,
      _roomPoints,
      widget.items,
      _wallHeight,
    );
  }

  void _reset() {
    setState(() {
      _yaw = _defaultYaw;
      _pitch = _defaultPitch;
      _distance = _defaultDistance;
    });
  }

  void _setView(double yaw, double pitch) {
    setState(() {
      _yaw = yaw;
      _pitch = pitch;
    });
  }

  void _zoom(double factor) {
    setState(() {
      _distance = (_distance * factor)
          .clamp(_minDistance, _maxDistance)
          .toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    final target = _V3(
      widget.project.widthCm / 2,
      _wallHeight / 4,
      widget.project.lengthCm / 2,
    );

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              s.view3dTitle,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      label: Text(s.presetPerspective),
                      onPressed: () => _setView(_defaultYaw, _defaultPitch),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: Text(s.presetTop),
                      onPressed: () => _setView(0, 1.53),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: Text(s.presetFront),
                      onPressed: () => _setView(0, 0.12),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: Text(s.presetSide),
                      onPressed: () => _setView(math.pi / 2, 0.12),
                    ),
                    const SizedBox(width: 10),
                    FilterChip(
                      avatar: const Icon(Icons.view_in_ar_outlined, size: 16),
                      label: Text(s.showWalls),
                      selected: _showWalls,
                      onSelected: (value) => setState(() => _showWalls = value),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      _zoom(event.scrollDelta.dy > 0 ? 1.1 : 1 / 1.1);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _reset,
                    onScaleStart: (details) => _startDistance = _distance,
                    onScaleUpdate: (details) {
                      setState(() {
                        if (details.pointerCount >= 2) {
                          _distance = (_startDistance / details.scale)
                              .clamp(_minDistance, _maxDistance)
                              .toDouble();
                        } else {
                          _yaw -= details.focalPointDelta.dx * 0.008;
                          _pitch = (_pitch + details.focalPointDelta.dy * 0.008)
                              .clamp(0.05, 1.53)
                              .toDouble();
                        }
                      });
                    },
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: _ScenePainter(
                          scene: _scene,
                          yaw: _yaw,
                          pitch: _pitch,
                          distance: _distance,
                          target: target,
                          showWalls: _showWalls,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.wallHeightLabel('${_wallHeight.round()} cm'),
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Slider(
              min: 150,
              max: 400,
              divisions: 25,
              value: _wallHeight,
              onChanged: (value) {
                setState(() {
                  _wallHeight = value;
                  _scene = _Scene.build(
                    widget.project,
                    _roomPoints,
                    widget.items,
                    value,
                  );
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                s.hint3d,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Painter
// ----------------------------------------------------------------------

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scene,
    required this.yaw,
    required this.pitch,
    required this.distance,
    required this.target,
    required this.showWalls,
  });

  final _Scene scene;
  final double yaw;
  final double pitch;
  final double distance;
  final _V3 target;
  final bool showWalls;

  static final _V3 _light = const _V3(-0.45, 0.8, 0.4).unit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.canvas);

    final cam = _Camera(target, yaw, pitch, distance, size);

    _paintFloor(canvas, cam);

    if (showWalls) {
      final visible =
          scene.walls.where((face) => _facesCamera(face, cam)).toList()..sort(
            (a, b) => (cam.pos - b.center).length.compareTo(
              (cam.pos - a.center).length,
            ),
          );

      for (final face in visible) {
        _drawFace(canvas, cam, face);
      }
    }

    final items =
        <_ItemModel>[...scene.items, if (showWalls) ...scene.wallItems]..sort(
          (a, b) => (cam.pos - b.center).length.compareTo(
            (cam.pos - a.center).length,
          ),
        );

    for (final item in items) {
      final host = item.hostNormal;
      final hostPoint = item.hostPoint;

      // Objek dinding ikut hilang bila dindingnya membelakangi kamera.
      if (host != null &&
          hostPoint != null &&
          host.dot(cam.pos - hostPoint) <= 0) {
        continue;
      }

      if (item.isMesh) {
        _drawMesh(canvas, cam, item);
        continue;
      }

      final sides = item.faces.sublist(0, item.faces.length - 1)
        ..sort(
          (a, b) => (cam.pos - b.center).length.compareTo(
            (cam.pos - a.center).length,
          ),
        );

      for (final face in sides) {
        _drawFace(canvas, cam, face);
      }

      _drawFace(canvas, cam, item.faces.last, outline: true);
    }
  }

  /// Model impor: semua segitiga diurutkan jauh ke dekat, digambar dua sisi
  /// supaya model dengan arah sisi tidak konsisten tetap tampak utuh.
  void _drawMesh(Canvas canvas, _Camera cam, _ItemModel item) {
    final faces = item.faces;
    final centers = item.faceCenters;
    final n = faces.length;

    final keys = List<double>.filled(n, 0);

    for (var i = 0; i < n; i++) {
      final c = centers[i];
      final dx = c.x - cam.pos.x;
      final dy = c.y - cam.pos.y;
      final dz = c.z - cam.pos.z;

      keys[i] = dx * dx + dy * dy + dz * dz;
    }

    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => keys[b].compareTo(keys[a]));

    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeJoin = StrokeJoin.round;

    for (final i in order) {
      final face = faces[i];
      final pts = <Offset>[];
      var visible = true;

      for (final p in face.points) {
        final o = cam.project(p);

        if (o == null) {
          visible = false;
          break;
        }

        pts.add(o);
      }

      if (!visible) continue;

      var normal = face.normal;

      if (normal.dot(cam.pos - face.points.first) < 0) normal = normal * -1;

      final shade = 0.5 + 0.5 * math.max(0.0, normal.dot(_light));
      final color = Color.lerp(Colors.black, face.color, shade)!;

      final path = Path()..addPolygon(pts, true);

      fill.color = color;
      edge.color = color;

      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
  }
  
  bool _facesCamera(_Face face, _Camera cam) {
    return face.normal.dot(cam.pos - face.points.first) > 0;
  }

  void _drawFace(
    Canvas canvas,
    _Camera cam,
    _Face face, {
    bool outline = false,
  }) {
    if (!_facesCamera(face, cam)) return;

    final pts = <Offset>[];

    for (final p in face.points) {
      final o = cam.project(p);

      if (o == null) return;

      pts.add(o);
    }

    final shade = 0.5 + 0.5 * math.max(0.0, face.normal.dot(_light));
    final color = Color.lerp(Colors.black, face.color, shade)!;

    final path = Path()..addPolygon(pts, true);

    canvas.drawPath(path, Paint()..color = color);

    // Garis tipis sewarna menutup celah antar bidang.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline ? 1.2 : 0.7
        ..strokeJoin = StrokeJoin.round
        ..color = outline ? Color.lerp(Colors.black, face.color, 0.55)! : color,
    );
  }

  void _paintFloor(Canvas canvas, _Camera cam) {
    final pts = <Offset>[];

    for (final p in scene.floor) {
      final o = cam.project(_V3(p.dx, 0, p.dy));

      if (o == null) return;

      pts.add(o);
    }

    final path = Path()..addPolygon(pts, true);

    canvas.drawPath(path, Paint()..color = AppColors.canvasRoom);

    // Grid 1 meter di lantai, dipotong mengikuti bentuk ruangan.
    canvas.save();
    canvas.clipPath(path);

    final gridPaint = Paint()
      ..color = AppColors.gridMajor
      ..strokeWidth = 1;

    for (var x = (scene.minX / 100).ceil() * 100.0; x <= scene.maxX; x += 100) {
      final a = cam.project(_V3(x, 0, scene.minY));
      final b = cam.project(_V3(x, 0, scene.maxY));

      if (a != null && b != null) canvas.drawLine(a, b, gridPaint);
    }

    for (var z = (scene.minY / 100).ceil() * 100.0; z <= scene.maxY; z += 100) {
      final a = cam.project(_V3(scene.minX, 0, z));
      final b = cam.project(_V3(scene.maxX, 0, z));

      if (a != null && b != null) canvas.drawLine(a, b, gridPaint);
    }

    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.forest,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => true;
}
