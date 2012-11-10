#ifndef VGA_H
#define VGA_H
/* VGA driver */

void vga_print_char(char c);
void vga_new_line();
void vga_enable_cursor();
void vga_disable_cursor();
void vga_move_cursor(int line, int column);


#endif
