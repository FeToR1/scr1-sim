# Лабораторная работа № 2 — симуляция SCR1

## Задание: вариант 10

| Параметр | Значение |
| --- | --- |
| Исключение | Breakpoint |
| Тест | `dependencies/riscv-tests/isa/rv32mi/sbreak.S` |
| Reset Vector | `0x400` |
| Trap Vector | `0xA00` |
| Сообщение обработчика | `break break` |
| Рабочая ветка | `lab_scr1_sim` |

## Подготовка

Проект находится в `D:\Coding\risk-v\scr1-sim`.
Отчёт и сохранённые результаты находятся в `lab/`.

Для сборки используется Docker-образ `scr1-lab` на Ubuntu 24.04:

- GNU Make 4.3 и G++ 13.3.0;
- Verilator 5.052, собранный из исходников;
- Syntacore GCC 12.2.1 из SC-DT 2023.11 с поддержкой TLS.

Подмодули инициализированы на версиях, закреплённых в репозитории.
Список ISA-тестов ограничен `sbreak.S`. Обработчик Breakpoint выводит
`break break`. Параметры векторов ядра и linker-скрипты пока исходные.

## Сборка и запуск

При запущенном Docker Desktop в режиме Linux-контейнеров, из PowerShell:

```powershell
cd D:\Coding\risk-v\scr1-sim
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" scr1-lab sh -c "make clean && make TARGETS=riscv_isa"
```

Образ уже собран. После правок исходников достаточно `docker run`.
Для первой установки на другом компьютере или после изменения `Dockerfile`:

```powershell
docker build -t scr1-lab .
```

Папка проекта подключается к `/work`, результаты появляются в `build`
на Windows. Параметр `--rm` удаляет завершившийся контейнер, сохраняя образ
и файлы в подключённой папке.

## Проверка исходного проекта

До выбора отдельного теста команда `make clean && make` выполнена в Docker с исходными настройками
`CFG=MAX`, `BUS=AHB`, `TRACE=0`. Результат — **224 из 224 тестов PASS**.
Список выполненных тестов совпал со списком запрошенных.

| Набор | Количество тестов |
| --- | ---: |
| RISC-V ISA | 56 |
| RISC-V Compliance | 84 |
| RISC-V Architectural | 80 |
| isr_sample, CoreMark, Dhrystone, hello | 4 |

Сохранены результаты этого запуска:

- [test_results.txt](baseline/test_results.txt) — статусы тестов;
- [sim_results.txt](baseline/sim_results.txt) — вывод симуляции;
- [test_info.txt](baseline/test_info.txt) — список тестов;
- [environment.txt](baseline/environment.txt) — версии инструментов и коммиты;
- [sbreak.dump](baseline/sbreak.dump) — исходный дизассемблер теста;
- [image.txt](baseline/image.txt) — идентификатор проверенного Docker-образа.

Дамп подтверждает исходные адреса: `_start = 0x200`,
`trap_vector = 0x1C0`. По варианту они должны стать `0x400` и `0xA00`.

CoreMark запускается с `ITERATIONS=1`: контрольные суммы совпали с эталоном,
но он сообщает о длительности меньше 10 секунд и печатает `Errors detected`.
Окружение SCR1 отмечает тест как PASS; этот короткий запуск не является
действительным измерением производительности CoreMark.

## Выбор теста варианта 10

В `sim/tests/riscv_isa/rv32_tests.inc` вместо полного списка выбран один тест:

```make
rv32_isa_tests := isa/rv32mi/sbreak.S
```

Служебная переменная `ARCH_lowercase` сохранена для настройки флагов архитектуры
в Makefile ISA-тестов. Параметр `TARGETS=riscv_isa` выбирает только набор ISA;
содержимое `rv32_tests.inc` определяет конкретные тесты внутри этого набора.

После `make clean` выполнено `make TARGETS=riscv_isa` в готовом Docker-образе.
В `test_info` присутствует ровно одна запись `sbreak.hex`, результат —
**1 из 1 теста PASS**. Вывод сохранён в [sbreak_initial.log](sbreak_initial.log).
Дамп подтвердил прежние адреса `_start = 0x200` и `trap_vector = 0x1C0`.

Тест вызывает Breakpoint командой `sbreak`. Общий обработчик `trap_vector`
передаёт управление `mtvec_handler` из теста. Он проверяет причину исключения
`mcause = 3` и равенство `mepc` адресу метки `do_break`, затем переходит к `pass`.
Успешное завершение использует отдельное исключение `ecall`; общий обработчик
направляет его в код завершения симуляции. При добавлении сообщения нужно
различать Breakpoint и этот завершающий `ecall`.

## Вывод сообщения при Breakpoint

В `sim/tests/common/riscv_macros.h` после чтения `mcause` добавлена проверка
`CAUSE_BREAKPOINT` (3). Только для этого исключения выполняется переход
к `print_breakpoint`. Завершающий `ecall` сохраняет прежний путь обработки.

Цикл печати находится в секции `.text` перед `_run_test`:

- `t0` содержит адрес строки `break break\n`;
- `t1` содержит адрес вывода `0xF0000000`;
- `lbu` читает очередной символ в `t2`;
- `sb` записывает символ в порт, и testbench показывает его в консоли;
- нулевой байт завершает цикл переходом к `dispatch_trap`.

`dispatch_trap` выполняет штатный переход к `mtvec_handler` теста.
Регистры `mcause` и `mepc` кодом печати не изменяются; проверки теста сохранены.
Для ISA-теста не требуется вызывать C-функции и подготавливать C-стек.
Адрес строки загружается командой `la`. Строка размещена в `.rodata`,
после неё директива `.section .text` возвращает размещение в секцию кода.

Сам цикл вынесен из области между `trap_vector` и `_start`, чтобы дополнительные
инструкции не сдвинули стартовый адрес. Выполнение теста начинается с `_run_test`,
поэтому обычный старт программы пропускает код печати.

Повторный запуск `make clean && make TARGETS=riscv_isa` в Docker дал
**1 из 1 теста PASS**. Строка `break break` появилась ровно один раз.
Вывод сохранён в [sbreak_message.log](sbreak_message.log).
По дампу `_start = 0x200`, `trap_vector = 0x1C0` — адреса на этом этапе сохранены.

## Следующие шаги

1. Настроить векторы и размещение кода по адресам `0x400` и `0xA00`.
2. Выполнить симуляцию с трассировкой и сформировать VCD для GTKWave.
3. Сохранить итоговые `test_results.txt`, `*.dump`, `trace_mprf_diff_*.log`
   и `trace_csr_*.log` в `results/`.
4. Дополнить отчёт и закоммитить изменения.

Источники инструментов:
[Verilator](https://verilator.org/guide/latest/install.html),
[Syntacore SC-DT](https://syntacore.com/tools/development-tools/previous-releases).
