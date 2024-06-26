// ignore_for_file: unreachable_from_main, avoid_init_to_null

import "dart:io";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

typedef Process = ({String id, int arrivalTime, int burstTime, int priority});
typedef ProcessSpan = ({int start, int end, Process process});
typedef ProcessSlice = ({int start, Process process});

typedef GanttResultValue = ({
  int arrivalTime,
  int burstTime,
  int turnaroundTime,
  int waitingTime,
});
typedef GanttResult = Map<String, GanttResultValue>;

extension on (Process, int) {
  Process get process => this.$1;
  int get runningTime => this.$2;
}

extension<T> on List<T> {
  T dequeue() => removeAt(0);
  void enqueueAll(Iterable<T> values) => addAll(values);
}

Iterable<ProcessSlice> nonPreemptivePrioritySlices(List<Process> processes) sync* {
  (Process process, int runningTime)? currentRunning = null;
  List<Process> queue = <Process>[];
  int completedProcesses = 0;
  int currentTime = 0;
  while (completedProcesses < processes.length) {
    queue
      ..enqueueAll(processes.where((Process process) => process.arrivalTime == currentTime))
      ..sort((Process a, Process b) => a.priority - b.priority);

    if (currentRunning == null && queue.isNotEmpty) {
      currentRunning = (queue.dequeue(), 0);
    }

    if (currentRunning case (Process process, int runningTime)) {
      int newRunningTime = runningTime + 1;
      if (process.burstTime - newRunningTime <= 0) {
        completedProcesses += 1;
        currentRunning = null;
      } else {
        currentRunning = (process, newRunningTime);
      }
      yield (start: currentTime, process: process);
    }

    currentTime++;
  }
}

Iterable<ProcessSlice> preemptivePrioritySlices(List<Process> processes) sync* {
  List<(Process process, int runningTime)> queue = <(Process process, int runningTime)>[];
  int completedProcesses = 0;
  int currentTime = 0;
  while (completedProcesses < processes.length) {
    queue
      ..removeWhere(((Process, int) p) => p.process.burstTime - p.runningTime <= 0)
      ..addAll(processes.where((Process process) => process.arrivalTime == currentTime).map((Process p) => (p, 0)))
      ..sort(((Process, int) a, (Process, int) b) => a.process.priority - b.process.priority);

    if (queue.isEmpty) {
      currentTime++;
      continue;
    }

    // Since we are maintaining a priority queue,
    // the first element will always be the one with the highest priority.
    var (Process process, int runningTime) = queue.first;
    int newRunningTime = runningTime + 1;

    if (process.burstTime - newRunningTime <= 0) {
      completedProcesses += 1;
    }
    queue.first = (process, newRunningTime);
    yield (start: currentTime, process: process);

    currentTime++;
  }
}

/// Converts an iterable of slices into an iterable of spans.
/// It run a RLE algorithm to group the slices by process.
///
/// For example: a list of slices like: A A A B B A A B C C C D A A A E
/// Becomes: A3 B2 A2 B1 C3 D1 A3 E1.
///
/// The result can be used to generate a Gantt chart.
Iterable<ProcessSpan> slicesToSpans(Iterable<ProcessSlice> processes) sync* {
  Process? lastProcess;
  int? lastStart;
  int currentTime = 0;

  for (var (:int start, :Process process) in processes) {
    if (lastProcess != null && lastStart != null && lastProcess.id != process.id) {
      stdout.write("(${lastProcess.id}, $lastStart, $currentTime) ");
      yield (start: lastStart, end: currentTime, process: lastProcess);

      lastStart = null;
      lastProcess = null;
    }

    lastStart ??= start;
    lastProcess ??= process;
    currentTime++;
  }
  if (lastProcess != null && lastStart != null) {
    yield (start: lastStart, end: currentTime, process: lastProcess);
    stdout.writeln("(${lastProcess.id}, $lastStart, $currentTime) ");
  }
}

Iterable<ProcessSpan> nonPreemptivePriority(List<Process> processes) sync* {
  yield* slicesToSpans(nonPreemptivePrioritySlices(processes));
}

Iterable<ProcessSpan> preemptivePriority(List<Process> processes) sync* {
  yield* slicesToSpans(preemptivePrioritySlices(processes));
}

int computeWaitingTime(List<ProcessSpan> executedChart, Process process) {
  ProcessSpan firstSpan = executedChart.firstWhere((ProcessSpan span) => span.process.id == process.id);
  int waitingTime = firstSpan.start - firstSpan.process.arrivalTime;

  for (int j = executedChart.length - 1; j >= 0; --j) {
    for (int i = j - 1; i >= 0; --i) {
      ProcessSpan left = executedChart[i];
      ProcessSpan right = executedChart[j];

      if (left.process.id == process.id && right.process.id == process.id) {
        waitingTime += right.start - left.end;

        j = i + 1;
        break;
      }
    }
  }

  return waitingTime;
}

GanttResult processGanttChart(Iterable<ProcessSpan> spans) {
  List<ProcessSpan> executedChart = spans.toList();
  List<Process> processes = executedChart.map((ProcessSpan span) => span.process).toSet().toList();
  Map<String, GanttResultValue> result = <String, GanttResultValue>{};

  for (Process process in processes) {
    int arrivalTime = process.arrivalTime;
    int burstTime = process.burstTime;
    int turnaroundTime = executedChart
        .where((ProcessSpan span) => span.process.id == process.id)
        .map((ProcessSpan span) => span.end - span.process.arrivalTime)
        .reduce(math.max);
    int waitingTime = computeWaitingTime(executedChart, process);
    result[process.id] = (
      arrivalTime: arrivalTime,
      burstTime: burstTime,
      turnaroundTime: turnaroundTime,
      waitingTime: waitingTime,
    );
  }

  return result;
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

enum Algorithm {
  preemptivePriority,
  nonPreemptivePriority,
}

class ExecuteAlgorithm extends Notification {
  const ExecuteAlgorithm(this.processes, this.algorithm);

  final List<Process> processes;
  final Algorithm algorithm;
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
        ImmutableList<ProcessSpan> spans = switch (notification.algorithm) {
          Algorithm.preemptivePriority => preemptivePriority,
          Algorithm.nonPreemptivePriority => nonPreemptivePriority,
        }(notification.processes)
            .toImmutableList();

        setState(() {
          this.sequence = spans;
          this.ganttResult = processGanttChart(spans);
        });

        return true;
      },
      child: AlgorithmResult(
        spans: sequence,
        result: ganttResult,
        child: const Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: <double>[0.1, 0.5, 1.0],
                colors: <Color>[
                  Color.fromARGB(255, 236, 221, 169),
                  Color.fromARGB(255, 238, 181, 196),
                  Color.fromARGB(255, 152, 176, 220),
                ],
              ),
            ),
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
  late Algorithm algorithm;

  static const List<Process> processes = <Process>[
    // (id: "A", arrivalTime: 2, burstTime: 6, priority: 3),
    // (id: "B", arrivalTime: 5, burstTime: 2, priority: 1),
    // (id: "C", arrivalTime: 1, burstTime: 8, priority: 0),
    // (id: "D", arrivalTime: 1, burstTime: 3, priority: 2),
    // (id: "E", arrivalTime: 4, burstTime: 4, priority: 1),

    (id: "P1", arrivalTime: 0, burstTime: 6, priority: 3),
    (id: "P2", arrivalTime: 5, burstTime: 2, priority: 1),
    (id: "P3", arrivalTime: 2, burstTime: 1, priority: 2),
    (id: "P4", arrivalTime: 7, burstTime: 8, priority: 1),
    (id: "P5", arrivalTime: 8, burstTime: 3, priority: 2),
  ];

  @override
  void initState() {
    super.initState();

    algorithm = Algorithm.nonPreemptivePriority;
    controllers = <ImmutableList<TextEditingController>>[
      for (Process process in processes)
        <TextEditingController>[
          TextEditingController(text: process.id),
          TextEditingController(text: process.arrivalTime.toString()),
          TextEditingController(text: process.burstTime.toString()),
          TextEditingController(text: process.priority.toString()),
        ].asImmutable(),
    ];
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
          color: const Color.fromARGB(255, 249, 253, 249),
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
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        switch (algorithm) {
                          case Algorithm.preemptivePriority:
                            algorithm = Algorithm.nonPreemptivePriority;
                          case Algorithm.nonPreemptivePriority:
                            algorithm = Algorithm.preemptivePriority;
                        }
                      });
                    },
                    child: Text(
                      switch (algorithm) {
                        Algorithm.preemptivePriority => "Priority Scheduling (P)",
                        Algorithm.nonPreemptivePriority => "Priority Scheduling (NP)",
                      },
                      style: const TextStyle(
                        fontSize: 18.0,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0XFF69585F),
                        color: Color(0XFF69585F),
                      ),
                    ),
                  ),
                ),
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
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll<Color>(Color(0xFF465775)),
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

                    ExecuteAlgorithm(processes, algorithm).dispatch(context);
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
                    child: Text("ID", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      children: <Widget>[
                        Text("Arrival", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Time", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
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
                      children: <Widget>[
                        Text("Burst", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Time", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              DataColumn(
                label: Expanded(
                  key: sizingKeys[3],
                  child: const Center(
                    child: Text("Priority", style: TextStyle(fontWeight: FontWeight.bold)),
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
  const OutputArea({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.0),
        color: const Color.fromARGB(255, 249, 253, 249),
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
            if (AlgorithmResult.of(context) case AlgorithmResult(:ImmutableList<ProcessSpan> spans?)) ...<Widget>[
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
    if (value == 0) {
      return 4.0;
    }

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
            color: const Color.fromARGB(255, 81, 124, 131),
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
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: const Color.fromARGB(255, 81, 124, 131)),
                                color: const Color.fromARGB(255, 157, 210, 218),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color.fromARGB(25, 0, 0, 0),
                                    offset: Offset(2, 2),
                                    blurRadius: 2.0,
                                    spreadRadius: 1.0,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                              child: Center(child: Text(span.process.id)),
                            ),
                            if (spans.first != span)
                              Transform.translate(
                                offset: Offset(-approximateOffset(span.end), 41.0),
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
        DataColumn(
          label: Text(
            "ID",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            "Burst Time",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            "Arrival Time",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            "Turnaround Time",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            "Waiting Time",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
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
