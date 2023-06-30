import 'dart:convert';
import 'dart:math';

import 'package:drag_drop/GridViewDrag/model/seat_type_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../model/coordinate_model.dart';
import '../model/seat_model.dart';

part 'drag_drop_state.dart';

class DragDropCubit extends Cubit<DragDropState> {
  final BuildContext context;
  final ScrollController sController = ScrollController();
  List<SeatTypeModel> sTypes = const [
    SeatTypeModel(
      name: "A1",
      icon: "asset/images/a1.png",
      height: 6,
      width: 6,
    ),
    SeatTypeModel(
      name: "wheel",
      icon: "asset/images/wheel.png",
      height: 9,
      width: 8,
    ),
    SeatTypeModel(
      name: "Door",
      icon: "asset/images/door.png",
      height: 7,
      width: 5,
    ),
  ];
  List<SeatModel> seats = [];

  late final double sHeight;
  late final double sWidth;
  late final double appBarHeight;
  late final Box gridBox;

  int crossAxisCount = 25;
  double vWidth = 48;
  double paddingH = 10;
  double gridTM = 20;

  late int gridGap;
  late double seatTypeH;
  late double buttonH;
  late double gridBM;
  late double gridWidth;
  late double gridHeight;
  late double gridSH;
  late int mainAxisCount;

  DragDropCubit(this.context) : super(DragDropInitial()) {
    sHeight = MediaQuery.of(context).size.height;
    sWidth = MediaQuery.of(context).size.width;
    appBarHeight = AppBar().preferredSize.height;

    // Grid Spacing, Draggable Container Height, button height
    gridGap = (sWidth ~/ crossAxisCount);
    paddingH = (sWidth % crossAxisCount) / 2;
    seatTypeH = sHeight * .1;
    buttonH = sHeight * .05;

    double vSpacing = appBarHeight + seatTypeH + buttonH + gridTM;
    double gridWithVM = sHeight - vSpacing;
    gridBM = (gridWithVM % gridGap);
    mainAxisCount = (gridWithVM - gridBM) ~/ gridGap;

    // Grid Size
    gridHeight = (mainAxisCount * gridGap).toDouble();
    gridWidth = (crossAxisCount * gridGap).toDouble();

    gridSH = (mainAxisCount * gridGap).toDouble();
  }

  DragDrop get _getState => DragDrop(
        sController: sController,
        crossAxisCount: crossAxisCount,
        mainAxisCount: mainAxisCount,
        gridGap: gridGap,
        gridHeight: gridHeight,
        seatTypeH: seatTypeH,
        paddingH: paddingH,
        buttonH: buttonH,
        gridTM: gridTM,
        gridBM: gridBM,
        sTypes: sTypes,
        seats: seats,
        vWidth: vWidth,
      );

  widgetAlignment() {
    emit(_getState);
  }

  clearData() {
    seats = [];
    double vSpacing = appBarHeight + seatTypeH + buttonH + gridTM + gridBM;
    double gridWithVM = sHeight - vSpacing;
    mainAxisCount = gridWithVM ~/ gridGap;
    gridBox.clear();

    emit(_getState);
  }

  checkSeats() async {
    // Saved widgets data
    gridBox = await Hive.openBox("Grid");
    String? seatsData = gridBox.get("seats");
    String? dimensions = gridBox.get("dimensions");

    if (seatsData != null) {
      List<dynamic> list = jsonDecode(seatsData) as List;
      seats = list.map((e) => SeatModel.fromJson(e)).toList();

      if (dimensions != null) {
        Map<String, dynamic> gD = jsonDecode(dimensions);
        int prevGG = gD["gridGap"];
        int prevMAC = gD["mainAxisCount"];

        if (prevGG != gridGap || prevMAC != mainAxisCount) {
          List<SeatModel> newSeats = seats.map((seat) {
            if (prevMAC > mainAxisCount) {
              mainAxisCount = prevMAC;
              gridSH = (mainAxisCount * gridGap).toDouble();
            }

            // New Coordinate
            double nDx = (seat.coordinate.dx / prevGG) * gridGap;
            double nDy = (seat.coordinate.dy / prevGG) * gridGap;

            // New Size
            double nH = (seat.height / prevGG) * gridGap;
            double nW = (seat.width / prevGG) * gridGap;

            return SeatModel(
              name: seat.name,
              icon: seat.icon,
              isWindowSeat: seat.isWindowSeat,
              isFoldingSeat: seat.isFoldingSeat,
              isReadingLights: seat.isReadingLights,
              height: nH,
              width: nW,
              heightInch: seat.heightInch,
              widthInch: seat.widthInch,
              coordinate: CoordinateModel(
                dx: nDx,
                dy: nDy,
              ),
            );
          }).toList();

          seats = newSeats;

          await gridBox.put(
            "seats",
            jsonEncode(seats.map((e) => e.toJson()).toList()),
          );
        }
      }
    }

    emit(_getState);

    await gridBox.put(
      "dimensions",
      jsonEncode({
        "gridGap": gridGap,
        "mainAxisCount": mainAxisCount,
      }),
    );
  }

  addSeat({
    required SeatTypeModel sType,
    required DraggableDetails details,
  }) async {
    double seatH =
        double.parse(((sType.height / vWidth) * gridWidth).toStringAsFixed(2));
    double seatW =
        double.parse(((sType.width / vWidth) * gridWidth).toStringAsFixed(2));

    // Checking if the dragged widget touches the grid area or not
    if (details.offset.dy + seatH - (seatH / 4) <
        (appBarHeight + seatTypeH + gridTM)) {
      return;
    }

    // New x coordinate of the dragged Widget
    double newLeft = details.offset.dx - paddingH;
    // The max x coordinate to which it can be moved
    double maxLeft = gridWidth - seatW - paddingH * 2;
    // final x coordinate inside the grid view
    double left = max(0, min(maxLeft, newLeft));

    // Adding the y coordinate scroll offset to position it in right place
    double yOffset = details.offset.dy + sController.offset;
    double newTop = yOffset - (appBarHeight + seatTypeH + gridTM);
    double maxTop = gridSH - seatH;
    double top = max(0, min(maxTop, newTop));

    // Alignment of widget along with the grid lines
    if (left % gridGap >= gridGap / 2) {
      left = left - (left % gridGap) + gridGap;
    } else {
      left = left - (left % gridGap);
    }

    if (top % gridGap >= gridGap / 2) {
      top = top - (top % gridGap) + gridGap;
    } else {
      top = top - (top % gridGap);
    }

    // Checking if the dragged widget collides with other widgets inside the grid area or not
    for (int i = 0; i < seats.length; i++) {
      CoordinateModel cn = seats[i].coordinate;
      double h = seats[i].height;
      double w = seats[i].width;

      bool xExist = cn.dx <= left && left < cn.dx + w ||
          left <= cn.dx && cn.dx < left + seatW;
      bool yExist = cn.dy <= top && top < cn.dy + h ||
          top <= cn.dy && cn.dy < top + seatH;

      if (xExist && yExist) return;
    }

    // if the dragged widget reaches the end of grid container
    if ((top + seatH) ~/ gridGap >= mainAxisCount - 1) {
      mainAxisCount += (seatH ~/ gridGap);
      gridSH = (mainAxisCount * gridGap).toDouble();

      await gridBox.put(
        "dimensions",
        jsonEncode({
          "gridGap": gridGap,
          "mainAxisCount": mainAxisCount,
        }),
      );
    }

    List<SeatModel> seatModels = seats.toList();

    seatModels.add(SeatModel(
      name: sType.name,
      icon: sType.icon,
      isWindowSeat: false,
      isFoldingSeat: false,
      isReadingLights: false,
      height: seatH,
      width: seatW,
      heightInch: sType.height,
      widthInch: sType.width,
      coordinate: CoordinateModel(dx: left, dy: top),
    ));

    seats = seatModels;

    emit(_getState);

    await gridBox.put(
      "seats",
      jsonEncode(seats.map((e) => e.toJson()).toList()),
    );
  }

  updatePosition({
    required int index,
    required DraggableDetails details,
  }) async {
    SeatModel seat = seats[index];

    double prevLeft = seat.coordinate.dx;
    double newLeft = details.offset.dx - paddingH;
    double maxLeft = sWidth - seat.width - paddingH * 2;
    double left = max(0, min(maxLeft, newLeft));

    double prevTop = seat.coordinate.dy;
    double yOffset = details.offset.dy + sController.offset;
    double newTop = yOffset - (appBarHeight + seatTypeH + gridTM);
    double maxTop = gridSH - seat.height;
    double top = max(0, min(maxTop, newTop));

    if (left != 0) {
      // Not modifying if the dragged widget touches the border
      double leftDif = left - prevLeft;
      if (leftDif < 0) {
        if ((leftDif * -1) % gridGap >= gridGap / 2) {
          left = left - (leftDif % gridGap);
        } else {
          left = left - (leftDif % gridGap) + gridGap;
        }
      } else {
        if (leftDif % gridGap >= gridGap / 2) {
          left = left - (leftDif % gridGap) + gridGap;
        } else {
          left = left - (leftDif % gridGap);
        }
      }
    }

    if (top != 0) {
      double topDif = top - prevTop;
      if (topDif < 0) {
        if ((topDif * -1) % gridGap >= gridGap / 2) {
          top = top - (topDif % gridGap);
        } else {
          top = top - (topDif % gridGap) + gridGap;
        }
      } else {
        if (topDif % gridGap >= gridGap / 2) {
          top = top - (topDif % gridGap) + gridGap;
        } else {
          top = top - (topDif % gridGap);
        }
      }
    }

    for (int i = 0; i < seats.length; i++) {
      CoordinateModel cn = seats[i].coordinate;
      double h = seats[i].height;
      double w = seats[i].width;

      // Not checking with the same widget
      if (cn.dx != prevLeft || cn.dy != prevTop) {
        bool xExist = cn.dx <= left && left < cn.dx + w ||
            left <= cn.dx && cn.dx < left + seat.width;
        bool yExist = cn.dy <= top && top < cn.dy + h ||
            top <= cn.dy && cn.dy < top + seat.height;

        if (xExist && yExist) return;
      }
    }

    if ((top + seat.height) ~/ gridGap >= mainAxisCount - 1) {
      mainAxisCount += (seat.height ~/ gridGap);
      gridSH = (mainAxisCount * gridGap).toDouble();

      await gridBox.put(
        "dimensions",
        jsonEncode({
          "gridGap": gridGap,
          "mainAxisCount": mainAxisCount,
        }),
      );
    }

    List<SeatModel> seatModels = seats.toList();

    seatModels[index] = SeatModel(
      name: seats[index].name,
      icon: seats[index].icon,
      isWindowSeat: seats[index].isWindowSeat,
      isFoldingSeat: seats[index].isFoldingSeat,
      isReadingLights: seats[index].isReadingLights,
      height: seats[index].height,
      width: seats[index].width,
      heightInch: seats[index].heightInch,
      widthInch: seats[index].widthInch,
      coordinate: CoordinateModel(dx: left, dy: top),
    );

    seats = seatModels;

    emit(_getState);

    await gridBox.put(
      "seats",
      jsonEncode(seats.map((e) => e.toJson()).toList()),
    );
  }

  updateSeat({
    required int index,
    required SeatModel seat,
    required int newHInch,
    required int newWInch,
  }) async {
    bool overlap = false;

    double seatH =
        double.parse(((newHInch / vWidth) * gridWidth).toStringAsFixed(2));
    double seatW =
        double.parse(((newWInch / vWidth) * gridWidth).toStringAsFixed(2));

    // Checking overlapping with other widgets with the new height and width
    if (seat.heightInch != newHInch || seat.widthInch != newWInch) {
      double left = seat.coordinate.dx;
      double top = seat.coordinate.dy;

      for (int i = 0; i < seats.length; i++) {
        CoordinateModel cn = seats[i].coordinate;
        double h = seats[i].height;
        double w = seats[i].width;

        if (cn.dx != left || cn.dy != top) {
          bool xExist = cn.dx <= left && left < cn.dx + w ||
              left <= cn.dx && cn.dx < left + seatW;
          bool yExist = cn.dy <= top && top < cn.dy + h ||
              top <= cn.dy && cn.dy < top + seatH;

          if (xExist && yExist) {
            overlap = true;
          }
        }
      }
    }

    // If does not overlap with other, then setting new size without exceeding the grid area
    double h = overlap ? seat.height : min(gridSH - seat.coordinate.dy, seatH);
    double w =
        overlap ? seat.width : min(gridWidth - seat.coordinate.dx, seatW);

    List<SeatModel> tempSeats = seats.toList();
    tempSeats[index] = SeatModel(
      name: seat.name,
      icon: seat.icon,
      isWindowSeat: seat.isWindowSeat,
      isFoldingSeat: seat.isFoldingSeat,
      isReadingLights: seat.isReadingLights,
      height: h,
      width: w,
      heightInch: overlap ? seat.heightInch : newHInch,
      widthInch: overlap ? seat.widthInch : newWInch,
      coordinate: seat.coordinate,
    );

    seats = tempSeats;
    emit(_getState);

    await gridBox.put(
      "seats",
      jsonEncode(seats.map((e) => e.toJson()).toList()),
    );
  }
}
