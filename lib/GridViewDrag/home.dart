import 'package:drag_drop/GridViewDrag/cubit/drag_drop_cubit.dart';
import 'package:drag_drop/GridViewDrag/widgets/seat_container.dart';
import 'package:drag_drop/GridViewDrag/widgets/seat_type_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    double sWidth = MediaQuery.of(context).size.width;

    return BlocProvider(
      create: (builder) => DragDropCubit(context)
        ..widgetAlignment()
        ..checkSeatExist(),
      child: Scaffold(
        appBar: AppBar(
          actions: [
            Builder(builder: (context) {
              return IconButton(
                onPressed: () =>
                    BlocProvider.of<DragDropCubit>(context)..clearData(),
                icon: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              );
            }),
          ],
        ),
        body: BlocBuilder<DragDropCubit, DragDropState>(
          builder: (context, state) {
            if (state is DragDrop) {
              return Stack(
                children: [
                  sTCList(
                    context: context,
                    gridGap: state.gridGap,
                    seatTypeS: state.seatTypeS,
                    mAll: state.mAll,
                    sTypes: state.sTypes,
                  ),
                  sCList(
                    context: context,
                    gridGap: state.gridGap,
                    seatTypeS: state.seatTypeS,
                    mAll: state.mAll,
                    mBottom: state.mBottom,
                    sWidth: sWidth,
                    sController: state.sController,
                    gridHeight:
                        (state.gridGap * state.mainAxisCount).toDouble(),
                    crossAxisCount: state.crossAxisCount,
                    gridLength: state.crossAxisCount * state.mainAxisCount,
                    seats: state.seats,
                  ),
                ],
              );
            }

            return Container();
          },
        ),
      ),
    );
  }
}
