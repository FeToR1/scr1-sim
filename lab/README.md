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
`break break`. Старт программы размещён на `0x400`, обработчик — на `0xA00`.

## Сборка и запуск

При запущенном Docker Desktop в режиме Linux-контейнеров, из PowerShell:

```powershell
cd D:\Coding\risk-v\scr1-sim
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/work" scr1-lab sh -c "make clean && make run_verilator_wf TARGETS=riscv_isa TRACE=1"
```

Образ уже собран. После правок исходников достаточно `docker run`.
Для первой установки на другом компьютере или после изменения `Dockerfile`:

```powershell
docker build -t scr1-lab .
```

Папка проекта подключается к `/work`, результаты появляются в `build`
на Windows. `TRACE=1` включает текстовый трейс, `run_verilator_wf` — VCD.
Параметр `--rm` удаляет завершившийся контейнер, сохраняя образ
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
`trap_vector = 0x1C0`. Требуемые значения по варианту — `0x400` и `0xA00`.

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

## Вывод сообщения при Breakpoint до переноса векторов

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

## Перенос векторов

В `src/includes/scr1_arch_description.svh` установлены:

```systemverilog
SCR1_ARCH_RST_VECTOR = 'h400;
SCR1_ARCH_MTVEC_BASE = 'hA00;
```

В `riscv_macros.h` стартовый код находится в `.text.init`,
обработчик — в отдельной `.text.trap`. Старые `.org 0xC0` и выравнивания
между обработчиком и стартом удалены.

В `link.ld` стартовый код размещается с адреса `0x400`, а `.text.trap` —
с `0xA00`. Служебные `SIM_EXIT` и `SIM_STOP` на `0xF4` и `0xF8` сохранены:
они нужны тестовому окружению для завершения симуляции.

После переноса выполнен запуск с `TRACE=1` и генерацией VCD.
Результат — **1 из 1 теста PASS**, сообщение `break break` выведено один раз.

| Проверка | Результат |
| --- | --- |
| ELF entry point и `_start` | `0x400` |
| `trap_vector` | `0xA00` |
| Breakpoint: `mcause` | `3` |
| Breakpoint: `mepc` | `0xA62`, адрес `do_break` |
| Переход при Breakpoint | `0xA62 → 0xA00` |
| Завершающий `ecall`: `mcause` | `11` |

Адреса проверены по дампу; переход в обработчик и причина исключения —
по трейсу. В VCD также проверены PC, `mtvec` и причина исключения.

## Итоговые результаты

Файлы сохранены в `results/`:

| Файл | Содержимое |
| --- | --- |
| [test_results.txt](../results/test_results.txt) | `sbreak.hex — OK — PASS` |
| [sbreak.dump](../results/sbreak.dump) | Дизассемблер с новыми адресами |
| [trace_mprf_diff_0.log](../results/trace_mprf_diff_0.log) | Изменения обычных регистров |
| [trace_csr_0.log](../results/trace_csr_0.log) | Записи CSR при исключениях |
| [tracelog_core_0.log](../results/tracelog_core_0.log) | Исходный объединённый трейс SCR1 |
| [sim_results.txt](../results/sim_results.txt) | Вывод сообщения и итог симуляции |
| [simx.vcd](../results/simx.vcd) | Временная диаграмма |

В этой версии SCR1 текстовый трейс объединён в `tracelog_core_0.log`.
Файлы MPRF и CSR получены фильтрацией его строк: записи `x00`–`x31`
отделены от записей CSR. Значения и время событий сохранены.
Промежуточный каталог `build/` в репозиторий не включается.

## Просмотр в GTKWave

GTKWave 3.3.100 для Windows установлен отдельно от Docker.
Загрузка итогового VCD проверена командой `--exit`: ошибок чтения нет.

Из корня проекта открыть диаграмму можно так:

```powershell
& "$env:LOCALAPPDATA\Programs\GTKWave\gtkwave64\bin\gtkwave.exe" .\results\simx.vcd
```

Для просмотра нужны сигналы `curr_pc` и поля `mtvec`, `mepc`, `mcause`
в структуре `csr_trace1` модуля трассировки. При Breakpoint значение `mcause`
равно `3`, `mepc` равно `0xA62`, а PC переходит на `0xA00`.

Источники инструментов:
[Verilator](https://verilator.org/guide/latest/install.html),
[Syntacore SC-DT](https://syntacore.com/tools/development-tools/previous-releases),
[GTKWave для Windows](https://sourceforge.net/projects/gtkwave/files/gtkwave-3.3.100-bin-win64/).
