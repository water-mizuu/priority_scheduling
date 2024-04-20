// ignore_for_file: unreachable_from_main

import "dart:io";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

typedef Process = ({String id, int arrivalTime, int burstTime, int priority});
typedef ProcessSpan = ({int start, int end, String id});

enum CpuState { waiting, running }

Iterable<ProcessSpan> priority(List<Process> processes) sync* {
  List<bool> completedProcesses = List<bool>.filled(processes.length, false);
  List<(int index, Process process)> queue = <(int index, Process process)>[];

  CpuState state = CpuState.waiting;

  (int index, Process process, int start, int span)? currentRunning;
  int currentTime = 0;

  bool run = true;
  do {
    run = false;

    for (int i = 0; i < processes.length; ++i) {
      Process process = processes[i];
      if (!completedProcesses[i] && process.arrivalTime == currentTime) {
        /// We have to add.
        if (queue.isEmpty) {
          queue.add((i, process));
        } else {
          /// Do insertion sort on the queue.
          for (int j = queue.length - 1; j >= 0; --j) {
            if ((queue[j].$2, process) case (Process(priority: int left), Process(priority: int right))
                when left < right) {
              queue.insert(j, (i, process));
              break;
            }
          }
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
          yield (start: start, end: currentTime, id: process.id);

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

    for (bool boolean in completedProcesses) {
      run |= !boolean;
    }
  } while (run);
}

void displayGanttChart(Iterable<ProcessSpan> ganttChart, [int length = 60]) {
  int totalSpan = ganttChart.last.end - ganttChart.first.start;
  List<int> spanPrintSizes = ganttChart //
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
  for (int i = 0; i < ganttChart.length; ++i) {
    ProcessSpan span = ganttChart.elementAt(i);
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
  fourthLine.write(ganttChart.first.start);
  for (var (int i, ProcessSpan span) in ganttChart.indexed) {
    int size = spanPrintSizes[i];
    fourthLine.write("${span.end}".padLeft(size));
  }
  stdout.writeln(fourthLine);
}

void main() {
  List<Process> processes = <Process>[
    (id: "P1", burstTime: 6, arrivalTime: 2, priority: 3),
    (id: "P2", burstTime: 2, arrivalTime: 5, priority: 1),
    (id: "P3", burstTime: 8, arrivalTime: 1, priority: 0),
    (id: "P4", burstTime: 3, arrivalTime: 0, priority: 2),
    (id: "P5", burstTime: 4, arrivalTime: 4, priority: 1),
  ];

  stdout.writeln("Priority:");
  displayGanttChart(priority(processes));

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
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
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
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              "Gantt Chart",
              style: GoogleFonts.nunito(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const GanttChart(),
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
        ),
      ),
    );
  }
}

class GanttChart extends StatelessWidget {
  const GanttChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class Results extends StatelessWidget {
  const Results({super.key});

  @override
  Widget build(BuildContext context) {
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
        const DataRow(
          cells: <DataCell>[
            DataCell(Text("P1")),
            DataCell(Text("6")),
            DataCell(Text("2")),
            DataCell(Text("10")),
            DataCell(Text("4")),
          ],
        ),
        const DataRow(
          cells: <DataCell>[
            DataCell(Text("P1")),
            DataCell(Text("6")),
            DataCell(Text("2")),
            DataCell(Text("10")),
            DataCell(Text("4")),
          ],
        ),
        const DataRow(
          cells: <DataCell>[
            DataCell(Text("P1")),
            DataCell(Text("6")),
            DataCell(Text("2")),
            DataCell(Text("10")),
            DataCell(Text("4")),
          ],
        ),
        const DataRow(
          cells: <DataCell>[
            DataCell(Text("P1")),
            DataCell(Text("6")),
            DataCell(Text("2")),
            DataCell(Text("10")),
            DataCell(Text("4")),
          ],
        ),
        DataRow(
          cells: <DataCell>[
            DataCell.empty,
            DataCell.empty,
            DataCell.empty,
            DataCell(Text("Average: 100 / 24 = ${((100 / 24) * 100).round() / 100}")),
            DataCell(Text("Average: 100 / 24 = ${((100 / 24) * 100).round() / 100}")),
          ],
        ),
      ],
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

  @override
  void initState() {
    super.initState();

    controllers = <ImmutableList<TextEditingController>>[];
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
                  fontWeight: FontWeight.bold,
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
              const SizedBox(height: 8.0),
              const Expanded(
                child: ProcessInput(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll<Color>(Color.fromARGB(255, 253, 175, 175)),
                  ),
                  onPressed: () {
                    /// Run the algorithm.
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

    return SingleChildScrollView(
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
          /// What we want:
          /// | ID | Arrival Time | Burst Time | Priority |
          /// |----|--------------|------------|----------|
          /// | A  |       0      |     4      |    3     |
          /// |    |              |            |    +     |
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
    );
  }
}
