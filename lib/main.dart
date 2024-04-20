// ignore_for_file: unreachable_from_main

import "dart:io";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

typedef Process = ({String id, int arrivalTime, int burstTime, int priority});
typedef ProcessSpan = ({int start, int end, String id, int arrivalTime, int burstTime, int priority});
typedef GanttResult = Map<String, ({int arrivalTime, int burstTime, int turnaroundTime, int waitingTime})>;

enum CpuState { waiting, running }

Iterable<ProcessSpan> priority(List<Process> processes) sync* {
  List<bool> completedProcesses = List<bool>.filled(processes.length, false);
  List<(int index, Process process)> queue = <(int index, Process process)>[];

  CpuState state = CpuState.waiting;

  (int index, Process process, int start, int span)? currentRunning;
  int currentTime = 0;

  while (completedProcesses.any((bool element) => !element)) {
    for (int i = 0; i < processes.length; ++i) {
      Process process = processes[i];
      if (!completedProcesses[i] && process.arrivalTime == currentTime) {
        /// We have to add.
        if (queue.isEmpty) {
          queue.add((i, process));
          continue;
        }

        bool hasAdded = false;
        for (int j = queue.length - 1; j >= 0; --j) {
          Process left = queue[j].$2;
          Process right = process;

          if (left.priority <= right.priority) {
            hasAdded = true;
            queue.insert(j + 1, (i, process));
            break;
          }
        }

        // [1, 3], 0
        //     ^   False
        // [1, 3], 0
        //  ^      False
        //
        if (!hasAdded) {
          queue.insert(0, (i, process));
        }
      }
    }

    switch ((state, currentRunning)) {
      case (CpuState.waiting, null):
        if (queue.isNotEmpty) {
          var (int index, Process process) = queue.removeAt(0);
          currentRunning = (index, process, currentTime, 1);
          state = CpuState.running;
        }
        currentTime++;
      case (CpuState.running, (int index, Process process, int start, int span)):
        if (span == process.burstTime) {
          /// The process has completed.
          completedProcesses[index] = true;
          yield (
            start: start,
            end: currentTime,
            id: process.id,
            arrivalTime: process.arrivalTime,
            burstTime: process.burstTime,
            priority: process.priority
          );

          /// Reset the state machine.
          currentRunning = null;
          state = CpuState.waiting;
        } else {
          currentRunning = (index, process, start, span + 1);

          currentTime++;
        }
      case _:
        throw StateError("Invalid State!");
    }
  }
}

GanttResult processGanttResult(Iterable<ProcessSpan> spans) {
  List<ProcessSpan> executedChart = spans.toList();

  return <String, ({int arrivalTime, int burstTime, int turnaroundTime, int waitingTime})>{
    for (ProcessSpan span in executedChart)
      span.id: (
        arrivalTime: span.arrivalTime,
        burstTime: span.burstTime,
        turnaroundTime: span.end - span.arrivalTime,
        waitingTime: span.start - span.arrivalTime,
      ),
  };
}

void displayGanttChart(Iterable<ProcessSpan> ganttChart, [int length = 60]) {
  List<ProcessSpan> executedChart = ganttChart.toList();
  int totalSpan = executedChart.last.end - executedChart.first.start;
  List<int> spanPrintSizes = executedChart //
      .map((ProcessSpan span) => (span.end - span.start) / totalSpan)
      .map((double ratio) => (ratio * length).floor())
      .toList();

  StringBuffer firstLine = StringBuffer();
  for (int size in spanPrintSizes) {
    firstLine.write("+${"-" * (size - 1)}");
  }
  firstLine.write("+");
  stdout.writeln(firstLine);

  StringBuffer secondLine = StringBuffer();
  for (int i = 0; i < executedChart.length; ++i) {
    ProcessSpan span = executedChart.elementAt(i);
    int size = spanPrintSizes[i];
    secondLine
      ..write("|")
      ..write(span.id.padLeft((size / 2).round()).padRight(size - 1));
  }
  secondLine.write("|");
  stdout.writeln(secondLine);

  StringBuffer thirdLine = StringBuffer();
  for (int size in spanPrintSizes) {
    thirdLine.write("+${"-" * (size - 1)}");
  }
  thirdLine.write("+");
  stdout.writeln(firstLine);

  StringBuffer fourthLine = StringBuffer();
  fourthLine.write(executedChart.first.start);
  for (var (int i, ProcessSpan span) in executedChart.indexed) {
    int size = spanPrintSizes[i];
    fourthLine.write("${span.end}".padLeft(size));
  }
  stdout.writeln(fourthLine);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Flutter Demo",
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: GoogleFonts.nunito().fontFamily,
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class AlgorithmResult extends InheritedWidget {
  const AlgorithmResult({
    required this.spans,
    required this.result,
    required super.child,
    super.key,
  });

  final ImmutableList<ProcessSpan>? spans;
  final GanttResult? result;

  static AlgorithmResult? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AlgorithmResult>();
  }

  @override
  bool updateShouldNotify(AlgorithmResult oldWidget) {
    return true;
  }
}

class ExecuteAlgorithm extends Notification {
  const ExecuteAlgorithm(this.processes);

  final List<Process> processes;
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  ImmutableList<ProcessSpan>? sequence;
  GanttResult? ganttResult;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ExecuteAlgorithm>(
      onNotification: (ExecuteAlgorithm notification) {
        ImmutableList<ProcessSpan> spans = priority(notification.processes).toImmutableList();

        displayGanttChart(spans);
        setState(() {
          this.sequence = spans;
          this.ganttResult = processGanttResult(spans);
        });

        return true;
      },
      child: AlgorithmResult(
        spans: sequence,
        result: ganttResult,
        child: const Scaffold(
          body: ColoredBox(
            color: Color(0xFFF7EAEA),
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          flex: 2,
                          child: InputArea(),
                        ),
                        SizedBox(width: 32.0),
                        Expanded(
                          flex: 5,
                          child: OutputArea(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ControllerRepository extends InheritedWidget {
  const ControllerRepository({
    required this.controllers,
    required void Function() addRow,
    required void Function() removeLastRow,
    required super.child,
    super.key,
  })  : this._addRow = addRow,
        this._removeLastRow = removeLastRow;

  final ImmutableList<ImmutableList<TextEditingController>> controllers;
  final void Function() _addRow;
  final void Function() _removeLastRow;

  static ControllerRepository? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ControllerRepository>();
  }

  @override
  bool updateShouldNotify(ControllerRepository oldWidget) {
    return true;
  }

  void addRow() {
    this._addRow();
  }

  void removeLastRow() {
    this._removeLastRow();
  }
}

class InputArea extends StatefulWidget {
  const InputArea({
    super.key,
  });

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  late final List<ImmutableList<TextEditingController>> controllers;

  static const List<Process> processes = <Process>[
    (id: "A", arrivalTime: 2, burstTime: 6, priority: 3),
    (id: "B", arrivalTime: 5, burstTime: 2, priority: 1),
    (id: "C", arrivalTime: 1, burstTime: 8, priority: 0),
    (id: "D", arrivalTime: 1, burstTime: 3, priority: 2),
    (id: "E", arrivalTime: 4, burstTime: 4, priority: 1),
  ];

  @override
  void initState() {
    super.initState();

    controllers = <ImmutableList<TextEditingController>>[];

    for (Process process in processes) {
      controllers.add(
        <TextEditingController>[
          TextEditingController(text: process.id),
          TextEditingController(text: process.arrivalTime.toString()),
          TextEditingController(text: process.burstTime.toString()),
          TextEditingController(text: process.priority.toString()),
        ].asImmutable(),
      );
    }
  }

  void addRow() {
    setState(() {
      controllers.add(
        <TextEditingController>[
          for (int i = 0; i < 4; ++i) TextEditingController(),
        ].asImmutable(),
      );
    });
  }

  void removeLatestRow() {
    setState(() {
      controllers.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ControllerRepository(
      controllers: controllers.asImmutable(),
      addRow: addRow,
      removeLastRow: removeLatestRow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.0),
          color: const Color(0xFFFFFFFF),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                "Input",
                style: GoogleFonts.nunito(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24.0),
              Text(
                "Algorithm",
                style: GoogleFonts.nunito(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text("Priority Scheduling", style: TextStyle(fontSize: 18.0)),
              ),
              const SizedBox(height: 24.0),
              Text(
                "Processes",
                style: GoogleFonts.nunito(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12.0),
              const Expanded(
                child: ProcessInput(),
              ),
              const SizedBox(height: 12.0),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll<Color>(Color(0xFFFDAFAF)),
                  ),
                  onPressed: () {
                    /// Run the algorithm.

                    List<Process> processes = <Process>[
                      for (ImmutableList<TextEditingController> controllerRow in controllers)
                        (
                          id: controllerRow[0].text,
                          arrivalTime: int.parse(controllerRow[1].text),
                          burstTime: int.parse(controllerRow[2].text),
                          priority: int.parse(controllerRow[3].text)
                        ),
                    ];

                    ExecuteAlgorithm(processes).dispatch(context);
                  },
                  child: const Text("Run"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension type ImmutableList<T>(List<T> inner) implements Iterable<T> {
  T operator [](int index) => inner[index];
}

extension ImmutableListExtension<T> on List<T> {
  ImmutableList<T> asImmutable() => ImmutableList<T>(this);
}

extension ImmutableIterableExtension<T> on Iterable<T> {
  ImmutableList<T> toImmutableList() => ImmutableList<T>(this.toList());
}

class ProcessInput extends StatefulWidget {
  const ProcessInput({super.key});

  @override
  State<ProcessInput> createState() => _ProcessInputState();
}

class _ProcessInputState extends State<ProcessInput> {
  late final List<GlobalKey> sizingKeys;

  List<double>? sizes;

  @override
  void initState() {
    super.initState();

    sizingKeys = <GlobalKey>[for (int i = 0; i < 4; ++i) GlobalKey()];

    /// Run after first render.
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      setState(() {
        sizes = <double>[for (GlobalKey key in sizingKeys) key.currentContext!.size!.width];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ControllerRepository? repository = ControllerRepository.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFC3C3C3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: SingleChildScrollView(
          child: DataTable(
            clipBehavior: Clip.hardEdge,
            border: TableBorder.all(color: const Color(0xFFC3C3C3), borderRadius: BorderRadius.circular(8.0)),
            horizontalMargin: 0,
            columnSpacing: 10,
            columns: <DataColumn>[
              DataColumn(
                label: Expanded(
                  key: sizingKeys[0],
                  child: const Center(
                    child: Text("ID"),
                  ),
                ),
              ),
              DataColumn(
                label: Expanded(
                  key: sizingKeys[1],
                  child: const Center(
                    child: Wrap(
                      direction: Axis.vertical,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[Text("Arrival"), Text("Time")],
                    ),
                  ),
                ),
              ),
              DataColumn(
                label: Expanded(
                  key: sizingKeys[2],
                  child: const Center(
                    child: Wrap(
                      direction: Axis.vertical,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[Text("Burst"), Text("Time")],
                    ),
                  ),
                ),
              ),
              DataColumn(
                label: Expanded(
                  key: sizingKeys[3],
                  child: const Center(
                    child: Text("Priority"),
                  ),
                ),
              ),
            ],
            rows: <DataRow>[
              if (repository?.controllers case ImmutableList<ImmutableList<TextEditingController>> controllers)
                for (ImmutableList<TextEditingController> controllerRow in controllers)
                  DataRow(
                    cells: <DataCell>[
                      for (var (int index, TextEditingController controller) in controllerRow.indexed)
                        DataCell(
                          SizedBox(
                            width: sizes?[index],
                            child: TextField(
                              controller: controller,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration.collapsed(
                                hintText: "",
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              DataRow(
                cells: <DataCell>[
                  DataCell(
                    Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            repository?.removeLastRow();
                          },
                          child: const Icon(Icons.remove),
                        ),
                      ),
                    ),
                  ),
                  DataCell.empty,
                  DataCell.empty,
                  DataCell(
                    Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            repository?.addRow();
                          },
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutputArea extends StatelessWidget {
  const OutputArea({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.0),
        color: const Color(0xFFFFFFFF),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "Output",
              style: GoogleFonts.nunito(
                fontSize: 32.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (AlgorithmResult.of(context) case AlgorithmResult(:ImmutableList<ProcessSpan> spans)) ...<Widget>[
              const SizedBox(height: 24.0),
              Text(
                "Gantt Chart",
                style: GoogleFonts.nunito(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GanttChart(spans: spans),
              const SizedBox(height: 24.0),
              Text(
                "Results",
                style: GoogleFonts.nunito(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Expanded(child: Results()),
            ],
          ],
        ),
      ),
    );
  }
}

class GanttChart extends StatelessWidget {
  const GanttChart({required this.spans, super.key});

  final ImmutableList<ProcessSpan> spans;

  static double approximateOffset(int value) {
    return (4 * (math.log(value) / math.log(10))).floorToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Transform.translate(
          offset: Offset(approximateOffset(spans.first.start), 32.0),
          child: Text(spans.first.start.toString()),
        ),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFFDAFAF),
            child: Stack(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (ProcessSpan span in spans) //
                      Expanded(
                        flex: span.end - span.start,
                        child: Stack(
                          children: <Widget>[
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color.fromARGB(255, 180, 125, 125)),
                                color: const Color(0xFFFDAFAF),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                              child: Center(child: Text(span.id)),
                            ),
                            if (spans.first != span)
                              Transform.translate(
                                offset: const Offset(0, 40.0),
                                child: Text(span.start.toString()),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(-approximateOffset(spans.last.end), 32.0),
          child: Text(spans.last.end.toString()),
        ),
      ],
    );
  }
}

class Results extends StatelessWidget {
  const Results({super.key});

  @override
  Widget build(BuildContext context) {
    GanttResult? result = AlgorithmResult.of(context)?.result;

    if (result case null) {
      return const SizedBox();
    }

    int totalTurnaroundTime = 0;
    int totalWaitingTime = 0;

    for (var (arrivalTime: _, burstTime: _, :int turnaroundTime, :int waitingTime) in result.values) {
      totalTurnaroundTime += turnaroundTime;
      totalWaitingTime += waitingTime;
    }

    int totalCount = result.length;
    double averageTurnaroundTime = (totalTurnaroundTime / totalCount * 100).round() / 100;
    double averageWaitingTime = (totalWaitingTime / totalCount * 100).round() / 100;

    return DataTable(
      border: TableBorder.all(
        color: const Color(0xFFC3C3C3),
        borderRadius: BorderRadius.circular(8.0),
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text("ID")),
        DataColumn(label: Text("Burst Time")),
        DataColumn(label: Text("Arrival Time")),
        DataColumn(label: Text("Turnaround Time")),
        DataColumn(label: Text("Waiting Time")),
      ],
      rows: <DataRow>[
        for (var MapEntry<String, ({int arrivalTime, int burstTime, int turnaroundTime, int waitingTime})>(
              key: String id,
              value: (:int arrivalTime, :int burstTime, :int turnaroundTime, :int waitingTime)
            ) in result.entries)
          DataRow(
            cells: <DataCell>[
              DataCell(Text(id)),
              DataCell(Text(burstTime.toString())),
              DataCell(Text(arrivalTime.toString())),
              DataCell(Text(turnaroundTime.toString())),
              DataCell(Text(waitingTime.toString())),
            ],
          ),
        DataRow(
          cells: <DataCell>[
            DataCell.empty,
            DataCell.empty,
            DataCell.empty,
            DataCell(Text("Average: $totalTurnaroundTime / $totalCount = $averageTurnaroundTime")),
            DataCell(Text("Average: $totalWaitingTime / $totalCount = $averageWaitingTime")),
          ],
        ),
      ],
    );
  }
}
