.386
.model flat, stdcall
option casemap:none

include windows.inc
include user32.inc
include kernel32.inc
include shell32.inc
include comctl32.inc
include gdi32.inc
include comdlg32.inc
include masm32.inc 
include advapi32.inc

includelib advapi32.lib
includelib user32.lib
includelib kernel32.lib
includelib shell32.lib
includelib comctl32.lib
includelib gdi32.lib
includelib comdlg32.lib
includelib masm32.lib
includelib msvcrt.lib
includelib winmm.lib  ; 需要包含用于 PlaySound 的库


WndProc PROTO :DWORD, :DWORD, :DWORD, :DWORD;窗口过程

PaintBoard PROTO :DWORD, :DWORD;绘制窗口

GenerateRandomNumberInRange PROTO :DWORD;生成随机数

TimerProc PROTO :DWORD, :DWORD, :DWORD, :DWORD;定时器过程

Random PROTO :DWORD;生成随机数

UpdateBarriers PROTO;更新障碍物

MoveBarriers PROTO :DWORD;移动障碍物

CheckCollision PROTO :DWORD;检测碰撞

PlayerDeath PROTO;玩家死亡

DoJump  PROTO :DWORD;跳跃

Block STRUCT
    x DWORD ?
    y DWORD ?
    wide DWORD ?
    height DWORD ?  
Block ENDS

Player STRUCT
    x DWORD ?
    y DWORD ?
Player ENDS

IDB_Background EQU 104
IDB_Player EQU 105
IDB_Barrier EQU 103

.data

    szClassName  DB 'Pleasejump', 0
    szAppName    DB 'jumpgame', 0

    isSpaceDown  BOOL FALSE

    hInstance    DD ?

    hBgImageList  DD ?
    hPlayerImageList DD ?
    hBarrierImageList DD ?


    nBottomY      DD 384
    nBottomX      DD 0
    rseed         DD ?

    ;originalBarrierHeight DD 120

    Barriers      Block 5 DUP (<>)
    PLAYER        Player <>
    ;NowBlock是Block类型的指针
    NowBlock      DD ?
    ;jumpStrength是玩家跳跃的力度
    jumpStrength  DD 0
    usablejumpStrength DD 0
    outputBuffer db 256 dup(0)   ; 输出缓冲区
    formatString db "Score:%d", 0      ; 格式化字符串

    vx0 DD 5    ; 水平初速度
    vy0 DD ?    ; 竖直初速度
    gravity DD 1  ; 重力加速度, 根据需要调整
    jumpTime DD 0   ; 跳跃已用时间
    Score DD 0; 游戏分数
    formattedString db 256 dup(?)
    buffer db "Score: %d",0
    overString db "Game Over",0
    scoreVal dd 0
    ;MusicFileName db "background.wav", 0
    
.code

WinMain PROC hInst:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hwnd:HWND

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    push hInst
    pop wc.hInstance
    mov wc.hbrBackground, COLOR_WINDOW + 1
    mov wc.lpszClassName, OFFSET szClassName
    mov wc.lpszMenuName, NULL
    mov wc.hIcon, NULL
    mov wc.hIconSm, NULL
    mov wc.hCursor, NULL
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL

    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax

    invoke RegisterClassEx, ADDR wc
    TEST eax, eax
    jz err

    invoke CreateWindowEx, NULL, OFFSET szClassName, OFFSET szAppName, \
           WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 500, 500, \
           NULL, NULL, hInst, NULL
    mov hwnd, eax

    invoke ShowWindow, hwnd, SW_SHOWNORMAL
    invoke UpdateWindow, hwnd

    .while TRUE
        invoke GetMessage, ADDR msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, ADDR msg
        invoke DispatchMessage, ADDR msg
    .endw

    mov eax, msg.wParam
    ret

err:    
    invoke MessageBox, NULL, OFFSET szAppName, OFFSET szAppName, MB_ICONERROR
    invoke ExitProcess, 0

WinMain ENDP

MoveBarriers PROC uses esi, hWnd:HWND
    mov esi, OFFSET Barriers
    mov eax, OFFSET PLAYER
    ; 检查第一个障碍物是否已到达初始位置
    cmp [esi].Block.x, 50  ; 假设初始位置的 X 坐标是 INITIAL_POSITION_X
    jle StopMoving

    .REPEAT
        sub [esi].Block.x, 1  ; 每次移动1像素
        add esi, TYPE Block
    .UNTIL esi >= OFFSET Barriers + SIZEOF Barriers
    sub [eax].Player.x, 1  ; 玩家也向左移动1像素
    ret

StopMoving:
    invoke KillTimer, hWnd, 2  ; 停止定时器
    ret
MoveBarriers ENDP

DoJump PROC uses ebx, hWnd:HWND
    ; 计算竖直初速度
    mov eax, jumpStrength
    imul eax, eax       ; 二次函数关系
    mov edx, 0     ; 100^2
    mov ecx, 125
    idiv ecx            ; 除以 100^2
    mov vy0, eax
    ; 设定水平初速度
    ;mov [vx0], HORIZONTAL_SPEED
    ; 重置跳跃时间
    mov jumpTime, 0

    ; 启动跳跃动画定时器
    invoke SetTimer, hWnd, 3, 33, NULL  ; 33ms ≈ 30 FPS,id=3
    ret
DoJump ENDP


UpdateBarriers PROC uses ebx ecx edx esi edi

    mov esi, OFFSET Barriers
    mov edi, esi
    add esi, SIZEOF Block  ; 跳过第一个元素
    .REPEAT
    ;将数组中的所有元素向前移动一位，抛弃第一个元素
    mov eax, [esi].Block.x
    mov [edi].Block.x, eax
    mov eax, [esi].Block.y
    mov [edi].Block.y, eax
    mov eax, [esi].Block.wide
    mov [edi].Block.wide, eax
    mov eax, [esi].Block.height
    mov [edi].Block.height, eax
    add esi, TYPE Block
    add edi, TYPE Block
    .UNTIL esi >= OFFSET Barriers + SIZEOF Barriers
    ; 在数组末尾添加新的障碍物
    invoke Random, 100
    mov ebx,eax
    mov edi, OFFSET Barriers
    mov eax, [edi + TYPE Block * 3].Block.x
    add eax, ebx ; 假设新的障碍物距离上一个200像素
    mov [edi + TYPE Block * 4].Block.x, eax
    mov [edi + TYPE Block * 4].Block.y, 440  ; 新障碍物的 Y 坐标
    mov [edi + TYPE Block * 4].Block.wide, 200
    mov [edi + TYPE Block * 4].Block.height, 220
    ret
UpdateBarriers ENDP

PlayerDeath PROC
    LOCAL scoreText[50]:BYTE

    ; 格式化分数文本
    invoke wsprintf, ADDR formattedString, ADDR buffer, scoreVal

    ; 显示分数窗口或对话框
    invoke MessageBox, NULL, ADDR formattedString, ADDR overString, MB_OK or MB_ICONINFORMATION

    ; 可以在这里重置游戏或执行其他逻辑
    push ebx
    push eax
    push ecx
    push edx

    mov ebx, OFFSET Barriers
    mov ecx,50
    mov edx,440
    mov scoreVal,0
    ;初始化当前障碍物
    push eax
    mov eax,OFFSET Barriers
    mov NowBlock,eax
    mov [eax].Block.x,ecx
    mov [eax].Block.y,edx
    pop eax
    ;初始化所有障碍物
    .REPEAT
    mov [ebx].Block.x,ecx
        mov [ebx].Block.y,edx
        mov [ebx].Block.wide,200
        mov [ebx].Block.height,220
        invoke Random,100
        add ecx ,eax
        add ebx,SIZEOF Block
        .UNTIL ebx >= OFFSET Barriers + SIZEOF Barriers
        
        mov ebx,OFFSET PLAYER
        mov [ebx].Player.x,125
        mov [ebx].Player.y,260

        pop edx
        pop ecx
        pop eax
        pop ebx
    ret
PlayerDeath ENDP

Random proc uses ecx edx,range:DWORD
    inc rseed
	mov eax, rseed
	mov ecx, 23
	mul ecx
	add eax, 7
	and eax, 0FFFFFFFFh
	ror eax, 1
	xor eax, rseed
	mov rseed, eax
	mov ecx, range
	xor edx, edx
	div ecx
	mov eax, edx
    add eax, 225
	ret

Random endp

WndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL hdc:HDC
    LOCAL ps:PAINTSTRUCT

    .if uMsg==WM_CREATE
        ;invoke PlaySound, ADDR MusicFileName, NULL, SND_ASYNC or SND_FILENAME or SND_LOOP
        invoke SetTimer, hWnd, 1, 50, NULL
        ;载入背景图片
        invoke ImageList_Create, 1000, 1000, ILC_COLOR16, 1, 0
        mov hBgImageList, eax
        invoke LoadBitmap, hInstance, IDB_Background
        invoke ImageList_AddMasked, hBgImageList, eax, 0
        invoke DeleteObject, eax
        ;载入玩家图片
        invoke ImageList_Create, 50, 80, ILC_COLOR16, 1, 0
        mov hPlayerImageList, eax
        invoke LoadBitmap, hInstance, IDB_Player
        invoke ImageList_AddMasked, hPlayerImageList, eax, 0
        invoke DeleteObject, eax
        ;载入障碍物图片
        invoke ImageList_Create, 200, 120, ILC_COLOR16, 1, 0
        mov hBarrierImageList, eax
        invoke LoadBitmap, hInstance, IDB_Barrier
        invoke ImageList_AddMasked, hBarrierImageList, eax, 0
        invoke DeleteObject, eax
        ;初始化游戏
        push ebx
        push eax
        push ecx
        push edx

        mov ebx, OFFSET Barriers
        mov ecx,50
        mov edx,440
        mov scoreVal,0
        ;初始化当前障碍物
        push eax
        mov eax,OFFSET Barriers
        mov NowBlock,eax
        mov [eax].Block.x,ecx
        mov [eax].Block.y,edx
        pop eax
        ;初始化所有障碍物
        .REPEAT
        mov [ebx].Block.x,ecx
        mov [ebx].Block.y,edx
        mov [ebx].Block.wide,200
        mov [ebx].Block.height,220
        invoke Random,100
        add ecx ,eax
        add ebx,SIZEOF Block
        .UNTIL ebx >= OFFSET Barriers + SIZEOF Barriers
        
        mov ebx,OFFSET PLAYER
        mov [ebx].Player.x,125
        mov [ebx].Player.y,260

        pop edx
        pop ecx
        pop eax
        pop ebx
        
        ;开始绘制
        invoke InvalidateRect, hWnd, NULL, TRUE
        invoke UpdateWindow, hWnd
        invoke DeleteObject, eax
    .elseif uMsg==WM_KEYDOWN
        .if wParam==VK_SPACE && isSpaceDown==FALSE
        ; 空格键按下
        mov isSpaceDown, TRUE
        mov jumpStrength, 0
        ; 启动定时器，假设定时器ID为1
        invoke SetTimer, hWnd, 1, 10, NULL  ; 定时器间隔10ms
        .endif
    .elseif uMsg==WM_KEYUP
        .if wParam==VK_SPACE
        ; 空格键释放
        mov isSpaceDown, FALSE
        invoke KillTimer, hWnd, 1
        ; 恢复障碍物的原始高度
        mov eax, OFFSET Barriers
        mov [eax].Block.height, 220
        mov eax, OFFSET PLAYER
        mov ebx,260
        mov [eax].Player.y,ebx
        ; 请求重绘窗口
        invoke InvalidateRect, hWnd, NULL, TRUE
        ;实现跳跃逻辑
        ;待实现
        invoke DoJump,hWnd
        mov jumpStrength,0
        

        ; 更新障碍物数组
        ;invoke UpdateBarriers
        ; 启动平移动画定时器，假设定时器ID为2
        ;invoke SetTimer, hWnd, 2, 10, NULL  ; 定时器间隔10ms
        .endif
    .elseif uMsg==WM_TIMER
        ; 定时器事件
        .if wParam==1 && isSpaceDown
        ; 定时器事件，用于减少障碍物高度
            mov eax, OFFSET Barriers
            mov ebx, [eax].Block.height
            sub ebx, 1  ; 每次减少1像素       
            cmp ebx, 60 ; 设置最小高度限制
            jle done
            add jumpStrength, 1;每次增加1点力度
            mov [eax].Block.height, ebx
            mov eax, OFFSET PLAYER
            add [eax].Player.y, 1
            ; 请求重绘窗口
            invoke InvalidateRect, hWnd, NULL, TRUE
            done:
        .endif
        ; 平移动画定时器
        .if wParam==2
            ; 平移动画定时器
            invoke MoveBarriers,hWnd
            ; 请求重绘窗口
            invoke InvalidateRect, hWnd, NULL, TRUE
        .endif
        .if wParam==3
        ;跳跃动画计时器
            ; 更新时间
            inc jumpTime
            ; 计算新位置
            ;mov eax, jumpTime
            ;mov ebx, eax
            ;imul ebx, vx0  ; 水平位移
            ;mov ecx, OFFSET PLAYER
            ;add [ecx].Player.x, ebx
            mov ecx, OFFSET PLAYER
            mov ebx,vx0
            add [ecx].Player.x, ebx

            mov eax, jumpTime
            mov ebx, eax
            imul ebx, eax  ; t^2
            imul ebx, gravity  ; 重力影响
            imul eax, vy0  ; vy0*t
            sub eax,ebx; vy0*t - g*t^2
            mov edx,260;
            sub edx,eax
            mov [ecx].Player.y, edx
            .if [ecx].Player.y > 261
                invoke CheckCollision,hWnd
            .endif    
            ; 检查是否到达 y=700
            ;cmp [ecx].Player.y, 700
            ;jge CheckCollision

            ; 请求重绘窗口
            invoke InvalidateRect, hWnd, NULL, TRUE
        .endif
    .elseif uMsg==WM_DESTROY
        invoke PostQuitMessage, 0
    .elseif uMsg==WM_PAINT
        invoke BeginPaint, hWnd, ADDR ps
        mov hdc, eax
        invoke PaintBoard, hWnd, ps.hdc
        invoke EndPaint, hWnd, ADDR ps
    .elseif uMsg==WM_ERASEBKGND
    ; 返回非零值，表明背景已处理
        mov eax, 1
        ret
    .else
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif
    xor eax, eax
    ret

WndProc ENDP

PaintBoard PROC uses ebx esi, hWin:HWND, hDC:HDC
    LOCAL mDC:HDC
    LOCAL rect:RECT
    LOCAL wRect:RECT
    LOCAL newHeight:DWORD
    LOCAL newY:DWORD
    LOCAL originalBarrierHeight:DWORD
    LOCAL scoreText[20]:BYTE  ; 用于存储分数字符串的数组
    LOCAL currentScore:DWORD

    ; 假设原始障碍物高度为120
    mov originalBarrierHeight, 120

    invoke CreateCompatibleDC, hDC
    mov mDC, eax
    invoke CreateCompatibleBitmap, hDC, 1000, 1000
    invoke SelectObject, mDC, eax
    push eax
    mov rect.left, 0
    mov rect.top, 0
    mov rect.right, 1000
    mov rect.bottom, 1000

    ; 绘制背景
    invoke ImageList_Draw, hBgImageList, 0, mDC, 0, 0, ILD_TRANSPARENT

    ; 绘制障碍物和玩家
    mov esi, OFFSET Barriers
    ; 绘制玩家
    mov eax, OFFSET PLAYER
    mov ebx, [eax].Player.x
    mov ecx, [eax].Player.y
    invoke ImageList_DrawEx, hPlayerImageList, 0, mDC, ebx, ecx, 50, 100, CLR_NONE, CLR_NONE, ILD_TRANSPARENT
    .REPEAT
        ; 获取障碍物的当前高度
        mov eax, [esi].Block.height
        mov newHeight, eax
        ; 计算新的 Y 坐标
        sub eax, originalBarrierHeight
        neg eax
        add eax, [esi].Block.y
        mov newY, eax

        ; 使用 ImageList_DrawEx 绘制障碍物
        mov eax, [esi].Block.x
        mov ebx, newY
        mov ecx, [esi].Block.wide
        mov edx, newHeight
        invoke ImageList_DrawEx, hBarrierImageList, 0, mDC, eax, ebx, ecx, edx, CLR_NONE, CLR_NONE, ILD_TRANSPARENT

        add esi, TYPE Block
    .UNTIL esi >= OFFSET Barriers + SIZEOF Barriers
    mov rect.left, 10     ; 距离窗口左边缘10像素
    mov rect.top, 10      ; 距离窗口顶部10像素
    mov rect.right, 200   ; 宽度足够显示分数文本
    mov rect.bottom, 50   ; 高度足够显示文本

    ; 将分数转换为字符串
     invoke wsprintf, ADDR formattedString, ADDR buffer, scoreVal
    ; 输出文本到窗口
    invoke lstrlen, OFFSET formattedString
    invoke TextOut, mDC, 10, 10, OFFSET formattedString, eax

    ; 将内存DC内容复制到主DC
    invoke GetClientRect, hWin, ADDR wRect
    invoke BitBlt, hDC, 0, 0, wRect.right, wRect.bottom, mDC, 0, 0, SRCCOPY

    pop eax
    invoke DeleteObject, eax
    invoke DeleteDC, mDC

    ret

PaintBoard ENDP

CheckCollision PROC uses ebx eax ecx edx, hWnd:HWND
    invoke KillTimer, hWnd, 3
    ; 固定玩家位置
    mov ebx,260
    mov ecx, OFFSET PLAYER
    mov [ecx].Player.y, ebx

    ; 检测玩家是否落在第一个障碍物上
    mov eax, OFFSET Barriers
    mov edx, [eax].Block.x
    mov ebx, [ecx].Player.x
    .if ebx > edx
    add edx, 200
        .if ebx <edx
        invoke SetTimer, hWnd, 2, 10, NULL
        ret
        .endif
    .endif
    ; 检测玩家是否落在第二个障碍物上
    mov eax, OFFSET Barriers
    add eax, SIZEOF Block
    mov edx, [eax].Block.x
    mov ebx, [ecx].Player.x
    .if ebx > edx
    add edx, 200
        .if ebx <edx
        invoke UpdateBarriers
        invoke SetTimer, hWnd, 2, 10, NULL
        add scoreVal,1
        ret
        .endif
    .endif
    ; 检测玩家是否落在第三个障碍物上
    mov eax, OFFSET Barriers
    add eax, SIZEOF Block
    add eax, SIZEOF Block
    mov edx, [eax].Block.x
    mov ebx, [ecx].Player.x
    .if ebx > edx
    add edx, 200
        .if ebx <edx
        invoke UpdateBarriers
        invoke UpdateBarriers
        invoke SetTimer, hWnd, 2, 10, NULL
        add scoreVal,1
        ret
        .endif
    .endif
    ; 检测玩家是否落在第四个障碍物上
    mov eax, OFFSET Barriers
    add eax, SIZEOF Block
    add eax, SIZEOF Block
    add eax, SIZEOF Block
    mov edx, [eax].Block.x
    mov ebx, [ecx].Player.x
    .if ebx > edx
    add edx, 200
        .if ebx <edx
        invoke UpdateBarriers
        invoke UpdateBarriers
        invoke UpdateBarriers
        invoke SetTimer, hWnd, 2, 10, NULL
        add scoreVal,1
        ret
        .endif
    .endif
    ; 检测玩家是否落在第五个障碍物上
    mov eax, OFFSET Barriers
    add eax, SIZEOF Block
    add eax, SIZEOF Block
    add eax, SIZEOF Block
    add eax, SIZEOF Block
    mov edx, [eax].Block.x
    mov ebx, [ecx].Player.x
    .if ebx > edx
    add edx, 200
        .if ebx <edx
        invoke UpdateBarriers
        invoke UpdateBarriers
        invoke UpdateBarriers
        invoke UpdateBarriers
        invoke SetTimer, hWnd, 2, 10, NULL
        add scoreVal,1
        ret
        .endif
    .endif
    invoke PlayerDeath
    ; 调用计分逻辑（待实现）
    ret

CheckCollision ENDP

start:
    invoke GetModuleHandle, NULL
    mov [hInstance], eax
    invoke InitCommonControls
    invoke WinMain, eax
    invoke ExitProcess, 0
end start
