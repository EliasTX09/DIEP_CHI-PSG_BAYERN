import math, os, sys
import pcbnew
from pcbnew import FromMM, VECTOR2I_MM

LIB = '/usr/share/kicad/footprints/'
OUT = os.path.expanduser('~/Dokumente/TEKKBOX_TX-16/Platinen')
os.makedirs(OUT, exist_ok=True)

class B:
    def __init__(self, name, w, h, title):
        self.name, self.w, self.h = name, w, h
        self.b = pcbnew.BOARD()
        self.b.SetCopperLayerCount(2)
        tb = self.b.GetTitleBlock(); tb.SetTitle(title); tb.SetRevision('0.1'); tb.SetCompany('TEKKBOX TX-16'); tb.SetDate('2026-10-05')
        self.nets = {}
        self.fps = {}
        try:
            ds = self.b.GetDesignSettings()
            nc = ds.m_NetSettings.GetDefaultNetclass()
            nc.SetTrackWidth(FromMM(0.25)); nc.SetClearance(FromMM(0.2)); nc.SetViaDiameter(FromMM(0.6)); nc.SetViaDrill(FromMM(0.3))
        except Exception as e:
            print('netclass:', e)
        self.rect(0, 0, w, h)

    def net(self, n):
        if n not in self.nets:
            ni = pcbnew.NETINFO_ITEM(self.b, n); self.b.Add(ni); self.nets[n] = ni
        return self.nets[n]

    def rect(self, x0, y0, x1, y1, r=1.0):
        # Umriss mit abgerundeten Ecken
        def seg(a, b):
            s = pcbnew.PCB_SHAPE(self.b); s.SetShape(pcbnew.SHAPE_T_SEGMENT); s.SetStart(VECTOR2I_MM(*a)); s.SetEnd(VECTOR2I_MM(*b))
            s.SetLayer(pcbnew.Edge_Cuts); s.SetWidth(FromMM(0.1)); self.b.Add(s)
        def arc(c, start, mid, end):
            s = pcbnew.PCB_SHAPE(self.b); s.SetShape(pcbnew.SHAPE_T_ARC); s.SetArcGeometry(VECTOR2I_MM(*start), VECTOR2I_MM(*mid), VECTOR2I_MM(*end))
            s.SetLayer(pcbnew.Edge_Cuts); s.SetWidth(FromMM(0.1)); self.b.Add(s)
        k = r * (1 - math.sqrt(0.5))
        seg((x0 + r, y0), (x1 - r, y0)); seg((x1, y0 + r), (x1, y1 - r)); seg((x1 - r, y1), (x0 + r, y1)); seg((x0, y1 - r), (x0, y0 + r))
        arc(None, (x1 - r, y0), (x1 - k, y0 + k), (x1, y0 + r)); arc(None, (x1, y1 - r), (x1 - k, y1 - k), (x1 - r, y1))
        arc(None, (x0 + r, y1), (x0 + k, y1 - k), (x0, y1 - r)); arc(None, (x0, y0 + r), (x0 + k, y0 + k), (x0 + r, y0))

    def fp(self, ref, lib, name, x, y, rot=0, value='', pads=None, side='F'):
        f = pcbnew.FootprintLoad(LIB + lib + '.pretty', name)
        if f is None:
            raise RuntimeError('Footprint fehlt: ' + lib + ':' + name)
        f.SetReference(ref); f.SetValue(value or name)
        f.SetPosition(VECTOR2I_MM(x, y)); f.SetOrientationDegrees(rot)
        self.b.Add(f)
        if side == 'B':
            f.Flip(f.GetPosition(), pcbnew.FLIP_DIRECTION_TOP_BOTTOM) if hasattr(pcbnew, 'FLIP_DIRECTION_TOP_BOTTOM') else f.Flip(f.GetPosition(), False)
        for p in f.Pads():
            n = (pads or {}).get(p.GetNumber())
            if n:
                p.SetNet(self.net(n))
        self.fps[ref] = f
        return f

    def text(self, s, x, y, size=1.0, layer=None, rot=0):
        t = pcbnew.PCB_TEXT(self.b); t.SetText(s); t.SetPosition(VECTOR2I_MM(x, y)); t.SetLayer(layer if layer is not None else pcbnew.F_SilkS)
        t.SetTextSize(VECTOR2I_MM(size, size)); t.SetTextThickness(FromMM(size * 0.15)); t.SetTextAngleDegrees(rot); self.b.Add(t)

    def zone(self, netname, layer):
        z = pcbnew.ZONE(self.b); z.SetLayer(layer); z.SetNet(self.net(netname))
        o = z.Outline(); o.NewOutline()
        for (x, y) in [(0.3, 0.3), (self.w - 0.3, 0.3), (self.w - 0.3, self.h - 0.3), (0.3, self.h - 0.3)]:
            o.Append(FromMM(x), FromMM(y))
        z.SetMinThickness(FromMM(0.25)); z.SetLocalClearance(FromMM(0.3)); z.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
        self.b.Add(z)

    def hole(self, ref, x, y):
        self.fp(ref, 'MountingHole', 'MountingHole_3.2mm_M3', x, y, value='M3')

    def save(self):
        pcbnew.ZONE_FILLER(self.b).Fill(self.b.Zones())
        path = os.path.join(OUT, self.name + '.kicad_pcb')
        pcbnew.SaveBoard(path, self.b)
        return path

C0603 = ('Capacitor_SMD', 'C_0603_1608Metric')
R0603 = ('Resistor_SMD', 'R_0603_1608Metric')
C0805 = ('Capacitor_SMD', 'C_0805_2012Metric')
SH = lambda n: ('Connector_JST', f'JST_SH_SM0{n}B-SRSS-TB_1x0{n}-1MP_P1.00mm_Horizontal')
LED2020 = ('LED_SMD', 'LED_WS2812B-2020_PLCC4_2.0x2.0mm')
LED5050 = ('LED_SMD', 'LED_WS2812B_PLCC4_5.0x5.0mm_P3.2mm')
SOIC16 = ('Package_SO', 'SOIC-16_3.9x9.9mm_P1.27mm')
SOT235 = ('Package_TO_SOT_SMD', 'SOT-23-5')
HC165 = lambda d, ser, qh: {'1': 'SH_LD', '2': 'CLK', '15': 'GND', '8': 'GND', '16': '+3V3', '10': ser, '9': qh,
                            '11': d[0], '12': d[1], '13': d[2], '14': d[3], '3': d[4], '4': d[5], '5': d[6], '6': d[7]}
LDO = {'1': '+5V', '3': '+5V', '2': 'GND', '5': '+3V3'}
CHAIN_IN = {'1': '+5V', '2': 'GND', '3': 'SH_LD', '4': 'CLK', '5': 'QH_OUT', '6': 'LED_IN', 'MP': 'GND'}
CHAIN_OUT = {'1': '+5V', '2': 'GND', '3': 'SH_LD', '4': 'CLK', '5': 'SER_IN', '6': 'LED_OUT', 'MP': 'GND'}

def led(b, ref, lib, x, y, rot, din, dout):
    # WS2812B: 1 DOUT, 2 GND, 3 DIN, 4 VDD
    b.fp(ref, lib[0], lib[1], x, y, rot, 'WS2812B' + ('-2020' if '2020' in lib[1] else ''), {'1': dout, '2': 'GND', '3': din, '4': '+5V'})

# ---------------------------------------------------------------- M1 Encoder-Spalte
def m1():
    W, H = 22.6, 72.0
    b = B('M1_Encoder-Spalte', W, H, 'TX-16 M1 Encoder-Spalte')
    cx, cy = W / 2, [12.8, 47.8]
    R = 9.8
    chain = 'LED_IN'; n = 0
    for e, y in enumerate(cy):
        # Encoder um -90 Grad gedreht: A/B/C-Pins oben, Taster-Pins unten in der Ring-Luecke
        b.fp(f'ENC{e+1}', 'Rotary_Encoder', 'RotaryEncoder_Alps_EC11E-Switch_Vertical_H20mm', cx + 2.5, y - 7.5, -90, 'EC11 20mm',
             {'A': f'ENC{e+1}_A', 'B': f'ENC{e+1}_B', 'C': 'GND', 'S1': f'ENC{e+1}_SW', 'S2': 'GND', 'MP': 'GND'})
        b.fp(f'SW{e+1}', 'Button_Switch_THT', 'SW_PUSH_6mm_H7.3mm', cx - 3.25, y - 2.25, 0, 'Taster 6x6 (statt Encoder)',
             {'1': f'ENC{e+1}_SW', '2': 'GND'})
        for k in range(15):
            a = math.radians(-135 + k * 270 / 14)
            n += 1
            nxt = 'LED_OUT' if (e == 1 and k == 14) else f'L{n}'
            rr = 11.0 if 5 <= k <= 9 else R
            led(b, f'D{n}', LED2020, cx + math.sin(a) * rr, y - math.cos(a) * rr, -math.degrees(a), chain, nxt)
            chain = nxt
    # Entkopplung der LED-Ringe
    for i, (x, y) in enumerate([(2.2, 2.4), (20.4, 2.4), (6.0, 57.6), (16.6, 57.6)]):
        b.fp(f'C{i+1}', *C0603, x, y, 0, '100nF', {'1': '+5V', '2': 'GND'})
    # Schieberegister + Pull-ups
    b.fp('U1', *SOIC16, cx, 29.4, 0, '74HC165', HC165(['ENC1_A', 'ENC1_B', 'ENC1_SW', 'ENC2_A', 'ENC2_B', 'ENC2_SW', '+3V3', '+3V3'], 'SER_IN', 'QH_OUT'))
    b.fp('C5', *C0603, 18.4, 34.0, 0, '100nF', {'1': '+3V3', '2': 'GND'})
    for i, (sig, x, y) in enumerate([('ENC1_A', 4.2, 25.0), ('ENC1_B', 4.2, 28.0), ('ENC1_SW', 4.2, 31.0),
                                     ('ENC2_A', 18.4, 25.0), ('ENC2_B', 18.4, 28.0), ('ENC2_SW', 18.4, 31.0)]):
        b.fp(f'R{i+1}', *R0603, x, y, 0, '10k', {'1': '+3V3', '2': sig})
    # Unterer Streifen: Stecker + 3,3-V-Regler
    b.fp('J1', *SH(6), 3.6, 65.6, -90, 'Kette IN', CHAIN_IN)
    b.fp('J2', *SH(6), W - 3.6, 65.6, 90, 'Kette OUT', CHAIN_OUT)
    b.fp('U2', *SOT235, cx, 63.0, 0, 'AP2112K-3.3', LDO)
    b.fp('C6', *C0603, cx - 2.6, 66.6, 90, '1uF', {'1': '+5V', '2': 'GND'})
    b.fp('C7', *C0603, cx + 2.6, 66.6, 90, '1uF', {'1': '+3V3', '2': 'GND'})
    b.fp('C8', *C0805, cx, 69.6, 0, '10uF', {'1': '+5V', '2': 'GND'})
    b.text('M1 ENC', cx, 60.4, 0.7)
    b.zone('GND', pcbnew.B_Cu)
    return b

# ---------------------------------------------------------------- M2 Tasten-Leiste
def m2():
    W, H = 92.0, 22.0
    b = B('M2_Tasten-Leiste', W, H, 'TX-16 M2 Tasten-Leiste')
    chain = 'LED_IN'
    for k in range(4):
        x = 11.5 + 23 * k
        b.fp(f'SW{k+1}', 'Button_Switch_THT', 'SW_PUSH_6mm_H7.3mm', x - 3.25, 6 - 2.25, 0, 'Taster 6x6', {'1': f'BTN{k+1}', '2': 'GND'})
        nxt = 'LED_OUT' if k == 3 else f'L{k+1}'
        led(b, f'D{k+1}', LED2020, x + 6.6, 6, 0, chain, nxt); chain = nxt
        b.fp(f'C{k+1}', *C0603, x + 6.6, 9.4, 0, '100nF', {'1': '+5V', '2': 'GND'})
        b.fp(f'R{k+1}', *R0603, x - 3.0, 13.5, 0, '10k', {'1': '+3V3', '2': f'BTN{k+1}'})
    b.fp('U1', *SOIC16, 46, 16.3, 90, '74HC165', HC165(['BTN1', 'BTN2', 'BTN3', 'BTN4', '+3V3', '+3V3', '+3V3', '+3V3'], 'SER_IN', 'QH_OUT'))
    b.fp('C5', *C0603, 53.5, 19.6, 0, '100nF', {'1': '+3V3', '2': 'GND'})
    b.fp('U2', *SOT235, 70.5, 16.5, 0, 'AP2112K-3.3', LDO)
    b.fp('C6', *C0603, 66.8, 19.4, 0, '1uF', {'1': '+5V', '2': 'GND'})
    b.fp('C7', *C0603, 74.2, 19.4, 0, '1uF', {'1': '+3V3', '2': 'GND'})
    b.fp('C8', *C0805, 24.0, 18.6, 0, '10uF', {'1': '+5V', '2': 'GND'})
    b.fp('J1', *SH(6), 3.6, 15.0, -90, 'Kette IN', CHAIN_IN)
    b.fp('J2', *SH(6), W - 3.6, 15.0, 90, 'Kette OUT', CHAIN_OUT)
    b.text('M2 BTN  TX-16', 36.0, 20.6, 0.8)
    b.zone('GND', pcbnew.B_Cu)
    return b

# ---------------------------------------------------------------- M3 Pad-Leiste
def m3():
    W, H = 112.0, 42.0
    b = B('M3_Pad-Leiste', W, H, 'TX-16 M3 Pad-Leiste')
    chain = 'LED_IN'; n = 0
    for k in range(4):
        x = 14 + 28 * k
        for dx in (-9.5, 9.5):
            n += 1; nxt = 'LED_OUT' if n == 8 else f'L{n}'
            led(b, f'D{n}', LED5050, x + dx, 5.5, 0, chain, nxt); chain = nxt
            b.fp(f'C{n}', *C0603, x + dx, 10.2, 0, '100nF', {'1': '+5V', '2': 'GND'})
        b.fp(f'J{k+4}', 'Connector_PinHeader_2.54mm', 'PinHeader_1x02_P2.54mm_Vertical', x - 1.27, 34.0, 90, f'FSR{k+1}', {'1': '+3V3', '2': f'FSR{k+1}'})
        b.fp(f'R{k+1}', *R0603, x + 6.0, 34.0, 0, '10k', {'1': f'FSR{k+1}', '2': 'GND'})
        b.text(f'PAD {k+1}', x, 17, 1.2); b.text('FSR 402 hier aufkleben', x, 19.2, 0.6)
    b.fp('J1', *SH(6), 28.0, 37.0, 180, 'Pads analog', {'1': '+3V3', '2': 'GND', '3': 'FSR1', '4': 'FSR2', '5': 'FSR3', '6': 'FSR4', 'MP': 'GND'})
    b.fp('J2', *SH(3), 56.0, 37.0, 180, 'LED IN', {'1': '+5V', '2': 'GND', '3': 'LED_IN', 'MP': 'GND'})
    b.fp('J3', *SH(3), 84.0, 37.0, 180, 'LED OUT', {'1': '+5V', '2': 'GND', '3': 'LED_OUT', 'MP': 'GND'})
    b.fp('C9', *C0805, 108.0, 38.5, 90, '10uF', {'1': '+5V', '2': 'GND'})
    b.text('M3 PADS  TX-16', 66.0, 40.6, 0.7)
    b.zone('GND', pcbnew.B_Cu)
    return b

# ---------------------------------------------------------------- M4 Controller
def m4():
    W, H = 100.0, 85.0
    b = B('M4_Controller', W, H, 'TX-16 M4 Controller')
    pico = {'1': 'MIDI_OUT_TX', '2': 'MIDI_RX', '4': 'TM_CLK', '5': 'TM_DIO', '6': 'MIDI_THRU_TX', '7': 'RELAY',
            '9': 'LED_MAIN_3V', '10': 'LED_PADS_3V', '11': 'MUX_S0', '12': 'MUX_S1', '14': 'TUBE_SCK', '15': 'TUBE_MOSI',
            '16': 'SDA_A', '17': 'SCL_A', '19': 'SDA_B', '20': 'SCL_B', '21': 'QH', '22': 'SH_LD', '24': 'CLK',
            '26': 'MUX_S2', '27': 'MUX_S3', '29': 'TUBE_CS', '31': 'MUX_SIG', '32': 'POT_MASTER', '34': 'POT_PHONES',
            '33': 'GND', '36': '+3V3', '39': 'VSYS'}
    for g in ('3', '8', '13', '18', '23', '28', '38'):
        pico[g] = 'GND'
    b.fp('U1', 'Module', 'RaspberryPi_Pico_Common_THT', 8.0, 14.0, 0, 'Raspberry Pi Pico 2', pico)
    b.fp('D1', 'Diode_SMD', 'D_SMA', 13.0, 72.0, 0, 'SS14', {'1': 'VSYS', '2': '+5V'})
    b.fp('U2', 'Package_DIP', 'DIP-14_W7.62mm', 38.0, 14.0, 0, '74AHCT125',
         {'1': 'GND', '2': 'LED_MAIN_3V', '3': 'LED_MAIN_5V', '4': 'GND', '5': 'LED_PADS_3V', '6': 'LED_PADS_5V', '7': 'GND',
          '9': 'GND', '10': 'GND', '12': 'GND', '13': 'GND', '14': '+5V'})
    b.fp('C1', *C0603, 42.0, 34.0, 0, '100nF', {'1': '+5V', '2': 'GND'})
    b.fp('R1', *R0603, 50.0, 18.0, 0, '33R', {'1': 'LED_MAIN_5V', '2': 'LED_MAIN'})
    b.fp('R2', *R0603, 50.0, 22.0, 0, '33R', {'1': 'LED_PADS_5V', '2': 'LED_PADS'})
    mux = {'1': 'MUX_SIG', '10': 'MUX_S0', '11': 'MUX_S1', '14': 'MUX_S2', '13': 'MUX_S3', '15': 'GND', '12': 'GND', '24': '+3V3'}
    for i, pin in enumerate(['9', '8', '7', '6', '5', '4', '3', '2', '23', '22', '21', '20', '19', '18', '17', '16']):
        mux[pin] = f'PAD{i+1}'
    b.fp('U3', 'Package_SO', 'SOIC-24W_7.5x15.4mm_P1.27mm', 70.0, 46.0, 0, 'CD74HC4067', mux)
    b.fp('C2', *C0603, 70.0, 56.4, 0, '100nF', {'1': '+3V3', '2': 'GND'})
    # MIDI
    b.fp('U4', 'Package_DIP', 'DIP-8_W7.62mm', 56.0, 14.0, 0, '6N138',
         {'2': 'MIDI_IN_A', '3': 'MIDI_IN5', '5': 'GND', '6': 'MIDI_RX', '7': 'OPTO_VB', '8': '+3V3'})
    b.fp('R3', *R0603, 60.0, 26.0, 0, '220R', {'1': 'MIDI_IN4', '2': 'MIDI_IN_A'})
    b.fp('D2', 'Diode_SMD', 'D_SOD-123', 60.0, 29.5, 0, '1N4148W', {'1': 'MIDI_IN_A', '2': 'MIDI_IN5'})
    b.fp('R4', *R0603, 66.0, 26.0, 0, '470R', {'1': '+3V3', '2': 'MIDI_RX'})
    b.fp('R5', *R0603, 66.0, 29.0, 0, '10k', {'1': 'OPTO_VB', '2': 'GND'})
    for i, (net, val, x, y) in enumerate([('MIDI_OUT4', '33R', 78, 24), ('MIDI_OUT5', '10R', 78, 27), ('MIDI_THRU4', '33R', 84, 24), ('MIDI_THRU5', '10R', 84, 27)]):
        src = '+3V3' if net.endswith('4') else ('MIDI_OUT_TX' if 'OUT' in net else 'MIDI_THRU_TX')
        b.fp(f'R{6+i}', *R0603, x, y, 0, val, {'1': src, '2': net})
    for i, (net, x, y) in enumerate([('SDA_A', 30, 62), ('SCL_A', 30, 65), ('SDA_B', 34, 62), ('SCL_B', 34, 65)]):
        b.fp(f'R{10+i}', *R0603, x, y, 90, '4k7', {'1': '+3V3', '2': net})
    b.fp('C3', 'Capacitor_THT', 'CP_Radial_D8.0mm_P3.50mm', 82.5, 64.0, 0, '470uF', {'1': '+5V', '2': 'GND'})
    b.fp('C4', *C0603, 20.0, 72.0, 90, '100nF', {'1': '+3V3', '2': 'GND'})
    # Stecker
    b.fp('J1', 'Connector_JST', 'JST_VH_B2P-VH_1x02_P3.96mm_Vertical', 88.0, 8.0, 0, '5V IN', {'1': '+5V', '2': 'GND'})
    b.fp('J9', 'Connector_JST', 'JST_PH_B7B-PH-K_1x07_P2.00mm_Vertical', 62.0, 5.0, 0, 'MIDI DIN',
         {'1': 'MIDI_IN4', '2': 'MIDI_IN5', '3': 'MIDI_OUT4', '4': 'MIDI_OUT5', '5': 'MIDI_THRU4', '6': 'MIDI_THRU5', '7': 'GND'})
    bottom = [('J5', 4, 'I2C A', {'1': 'GND', '2': '+3V3', '3': 'SDA_A', '4': 'SCL_A'}, 8),
              ('J6', 4, 'I2C B', {'1': 'GND', '2': '+3V3', '3': 'SDA_B', '4': 'SCL_B'}, 20),
              ('J7', 4, 'TM1637', {'1': 'GND', '2': '+3V3', '3': 'TM_CLK', '4': 'TM_DIO'}, 32),
              ('J8', 4, 'POTIS', {'1': 'GND', '2': '+3V3', '3': 'POT_MASTER', '4': 'POT_PHONES'}, 44),
              ('J2', 6, 'KETTE', {'1': '+5V', '2': 'GND', '3': 'SH_LD', '4': 'CLK', '5': 'QH', '6': 'LED_MAIN'}, 57),
              ('J4', 3, 'PAD-LED', {'1': '+5V', '2': 'GND', '3': 'LED_PADS'}, 69),
              ('J10', 6, 'ROEHRE', {'1': '+5V', '2': 'GND', '3': 'TUBE_SCK', '4': 'TUBE_MOSI', '5': 'TUBE_CS', '6': 'RELAY'}, 81)]
    for ref, n, label, pads, x in bottom:
        pads = dict(pads); pads['MP'] = 'GND'
        b.fp(ref, *SH(n), x, 80.5, 180, label, pads)
        b.text(label, x, 75.6, 0.7)
    for k in range(4):
        pads = {'1': '+3V3', '2': 'GND', 'MP': 'GND'}
        for j in range(4):
            pads[str(3 + j)] = f'PAD{k*4+j+1}'
        y = 22 + 12 * k
        b.fp(f'J3{chr(97+k)}', *SH(6), W - 3.6, y, 90, f'PADS {k*4+1}-{k*4+4}', pads)
        b.text(f'P{k*4+1}-{k*4+4}', W - 9.5, y, 0.7, rot=90)
    for i, (x, y) in enumerate([(4, 4), (W - 4, 70), (4, 72), (40, 4)]):
        b.hole(f'H{i+1}', x, y)
    b.text('TEKKBOX TX-16  M4 CONTROLLER  REV 0.1', 50, 66.5, 1.0)
    b.text('MIDI IN/OUT/THRU', 62, 9.6, 0.7)
    b.zone('GND', pcbnew.B_Cu)
    return b

if __name__ == '__main__':
    for mk in (m1, m2, m3, m4):
        bd = mk()
        print('gespeichert', bd.save(), 'Bauteile:', len(bd.fps), 'Netze:', len(bd.nets))
