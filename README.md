# Лабораторная работа 2

Вариант 10: исключение Breakpoint, тест `sbreak.S`.

Для сборки используется Docker-образ `scr1-lab`, содержащий Verilator и
RISC-V GCC

```powershell
cd D:\Coding\risk-v\scr1-sim
docker run --rm -it --mount "type=bind,source=$($PWD.Path),target=/work" scr1-lab bash
```
Исходники ISA-тестов находятся в `dependencies/riscv-tests/isa/`.
Для варианта 10 используется файл
`dependencies/riscv-tests/isa/rv32mi/sbreak.S`. Он подключает общий код
проверки из `dependencies/riscv-tests/isa/rv64si/sbreak.S`.

Для запуска можно выбрать его

```
make TARGETS=riscv_isa rv32_isa_tests=isa/rv32mi/sbreak.S
```

Или удалить все остальные в списке запускаемых ISA-тестов задаётся в
`sim/tests/riscv_isa/rv32_tests.inc`

```bash
make TARGETS=riscv_isa
```

в `sim/tests/common/riscv_macros.h` описаны макросы, из которых собирается программа теста. Макросы раскрываются в ассемблерный код при сборке

В макросе RVTEST_CODE_BEGIN определён общий обработчик исключений с меткой входа trap_vector. Обработчик читает причину исключения из регистра mcause и выбирает дальнейшее действие. По смыслу его работа похожа на цепочку if-else - для разных причин предусмотрены разные пути обработки

Также требуется чтобы код продолжал исполняться с адреса 0x400 - выставляем его, а также расположение trap vector. `src\includes\scr1_arch_description.svh`

```
// Default address constants (if scr1_arch_custom.svh is not used)
parameter bit [`SCR1_XLEN-1:0]          SCR1_ARCH_RST_VECTOR        = 'h400;            // Reset vector value (start address after reset)
parameter bit [`SCR1_XLEN-1:0]          SCR1_ARCH_MTVEC_BASE        = 'hA00;            // MTVEC.base field reset value, or constant value for MTVEC.base bits that are hardwired
```

Это говорит процессору, в какую ячейку обращаться для поиска кода

Для корректной работы в link.Id нужно указать куда разместить код.

```
.text.trap 0xA00 : {
    *(.text.trap) // обрабатывает все .section .text.trap
} >RAM
```

Запуск симуляции
```
make run_verilator TARGETS=riscv_isa TRACE=1
```

```
---Test:                       sbreak.hex
break break
Test passed

#--------------------------------------
# Summary: 1/1 tests passed
#--------------------------------------
```

А в файлах логов `results/sbreak.dump` видно

```
start address 0x00000400
00000400 <_start>:
00000a00 <trap_vector>:
00000a62 <do_break>:
```


А в `results/trace_mprf_diff_0.log` 

```
x06_t1  00000003 // ожидаемая причина 3
x05_t0  00000003 // произошедшая тоже 3
...
x05_t0  00000a62 // адрес do_break
```