

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class AnimatedBalanceCard extends StatefulWidget {
  final bool isDarkMode;
  final dynamic balance;

  const AnimatedBalanceCard({Key? key, required this.isDarkMode, this.balance})
    : super(key: key);

  @override
  _AnimatedBalanceCardState createState() => _AnimatedBalanceCardState();
}

class _AnimatedBalanceCardState extends State<AnimatedBalanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _isBalanceVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.balance.address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wallet address copied to clipboard'),
        backgroundColor: MangoPalette.green500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.all(20),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isDarkMode
                  ? [
                      MangoPalette.green600.withBlue(
                        20,
                      ), 
                      MangoPalette.green300.withGreen(140), 
                      Colors.lime.shade400.withOpacity(
                        0.2 * _animation.value,
                      ), 
                    ]
                  : [
                      MangoPalette.green800.withBlue(
                        10,
                      ), 
                      MangoPalette.green400.withGreen(120), 
                      Colors.lime.shade500.withOpacity(
                        0.2 * _animation.value,
                      ), 
                    ],
              stops: [
                0.0,
                0.6 + sin(_animation.value * 3.14) * 0.1, 
                1.0,
              ],
              transform: GradientRotation(
                _animation.value * 0.1, 
              ),
            ),
            borderRadius: BorderRadius.circular(MangoRadius.md),
            boxShadow: [
              BoxShadow(
                color: MangoPalette.green500.withOpacity(
                  0.3 + _animation.value * 0.1,
                ), 
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.lime.withOpacity(
                  0.1 * _animation.value,
                ), 
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Semantics(
                              label:
                                  'Total Mango tokens: ${widget.balance?.balance.toFixed(6) ?? '0'}',
                              child: Text(
                                'Wallet balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 4,),
                            MangoPressable(
                            onTap: () {
                              setState(() {
                                _isBalanceVisible = !_isBalanceVisible;
                              });
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(_isBalanceVisible ? 0.2 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isBalanceVisible 
                                    ? Icons.visibility_rounded 
                                    : Icons.visibility_off_rounded,
                                size: 7,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),

                          ],
                        ),
                        Semantics(
                          liveRegion: true,
                          child: MangoPressable(
                            onTap: () {
                              setState(() {
                                _isBalanceVisible = !_isBalanceVisible;
                              });
                            },
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    _isBalanceVisible
                                        ? TextSpan(
                                            text:
                                                '${widget.balance?.balance.toFixed(6) ?? '0.000000'} ',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -0.5,
                                            ),
                                          )
                                        : TextSpan(
                                            text: '_ _ _ ',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                            
                                    TextSpan(
                                      text: 'MNG',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: MangoPalette.black,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 500),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(
                              0.3 + _animation.value * 0.1,
                            ),
                            Colors.white.withOpacity(
                              0.1 + _animation.value * 0.05,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                        border: Border.all(
                          color: Colors.white.withOpacity(
                            0.5 + _animation.value * 0.1,
                          ),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MangoPalette.black.withOpacity(
                              0.2 + _animation.value * 0.1,
                            ),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.eco_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 80),
              AnimatedContainer(
                duration: Duration(milliseconds: 500),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.15 + _animation.value * 0.05,
                  ),
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Address',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          '${widget.balance.address.substring(0, 6)}...${widget.balance.address.substring(widget.balance.address.length - 4)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 8),
                    MangoPressable(
                      onTap: _copyToClipboard,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Spacer(),
                    SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            color: MangoPalette.black.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Reward Token',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
