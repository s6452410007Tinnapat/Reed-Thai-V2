import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/firebase_service.dart';
import 'shop_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Shop> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // ตัวกรองการค้นหา
  List<String> _selectedWreathTypes = [];
  RangeValues _priceRange = const RangeValues(1, 3);
  double _minRating = 0.0;
  
  // รายการประเภทพวงหรีด
  final List<String> _wreathTypes = [
    'พวงรีดดอกไม้สด',
    'พวงรีดผ้า',
    'พวงรีดพัดลม',
    'พวงรีดนาฬิกา',
    'พวงรีดอื่นๆ',
  ];

  @override
  void initState() {
    super.initState();
    // ค้นหาทั้งหมดเมื่อเปิดหน้าค้นหา
    _searchShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchShops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await FirebaseService.searchShops(
        keyword: _searchController.text,
        wreathTypes: _selectedWreathTypes.isEmpty ? null : _selectedWreathTypes,
        minPriceRange: _priceRange.start.round(),
        maxPriceRange: _priceRange.end.round(),
        minRating: _minRating,
      );
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดในการค้นหา: $e';
        _isLoading = false;
      });
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ตัวกรองการค้นหา',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ประเภทพวงหรีด',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _wreathTypes.map((type) {
                      final isSelected = _selectedWreathTypes.contains(type);
                      return FilterChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedWreathTypes.add(type);
                            } else {
                              _selectedWreathTypes.remove(type);
                            }
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.blueGrey[100],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ระดับราคา',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 1,
                    max: 3,
                    divisions: 2,
                    labels: RangeLabels(
                      '฿' * _priceRange.start.round(),
                      '฿' * _priceRange.end.round(),
                    ),
                    onChanged: (values) {
                      setModalState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('ราคาประหยัด'),
                      Text('ราคาปานกลาง'),
                      Text('ราคาสูง'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'คะแนนขั้นต่ำ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: _minRating.toStringAsFixed(1),
                    onChanged: (value) {
                      setModalState(() {
                        _minRating = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('0'),
                      Text('5'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedWreathTypes = [];
                              _priceRange = const RangeValues(1, 3);
                              _minRating = 0.0;
                            });
                          },
                          child: const Text('รีเซ็ต'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              // อัปเดตตัวแปรในหน้าหลัก
                              _selectedWreathTypes = List.from(_selectedWreathTypes);
                              _priceRange = _priceRange;
                              _minRating = _minRating;
                            });
                            _searchShops();
                          },
                          child: const Text('ค้นหา'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาร้านพวงหรีด'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'ตัวกรองการค้นหา',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาร้านพวงหรีด...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchShops();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onSubmitted: (_) => _searchShops(),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_selectedWreathTypes.isNotEmpty || _minRating > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('ตัวกรอง: '),
                  if (_selectedWreathTypes.isNotEmpty)
                    Chip(
                      label: Text('${_selectedWreathTypes.length} ประเภท'),
                      onDeleted: () {
                        setState(() {
                          _selectedWreathTypes = [];
                        });
                        _searchShops();
                      },
                    ),
                  const SizedBox(width: 8),
                  if (_minRating > 0)
                    Chip(
                      label: Text('คะแนน ≥ ${_minRating.toStringAsFixed(1)}'),
                      onDeleted: () {
                        setState(() {
                          _minRating = 0;
                        });
                        _searchShops();
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _searchShops,
                              child: const Text('ลองใหม่'),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'ไม่พบร้านพวงหรีดที่ตรงกับการค้นหา',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            padding: const EdgeInsets.all(8),
                            itemBuilder: (context, index) {
                              final shop = _searchResults[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ShopDetailScreen(shop: shop),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (shop.imageUrl != null)
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          child: Image.network(
                                            shop.imageUrl!,
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                height: 150,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      else
                                        Container(
                                          height: 150,
                                          width: double.infinity,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.store,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              shop.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.star, color: Colors.amber, size: 16),
                                                Text(' ${shop.rating}'),
                                                const SizedBox(width: 16),
                                                Text('฿' * shop.priceRange),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              shop.address,
                                              style: TextStyle(color: Colors.grey[600]),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: shop.wreathTypes.map((type) {
                                                return Chip(
                                                  label: Text(
                                                    type,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  backgroundColor: Colors.blueGrey[50],
                                                  padding: EdgeInsets.zero,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
