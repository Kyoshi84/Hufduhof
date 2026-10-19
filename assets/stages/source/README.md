# Panorama źródłowa Hufduhofu

`hufduhof_panorama.png` (2172x724) – obraz wzorcowy dostarczony przez autora. Z niego powstają warstwy tła
wszystkich etapów (`sky`, `far1`, `far2`, `ground`, `foreground`):

    python3 tools/build_stage_backgrounds.py                 # przebudowa PNG w assets/stages/<etap>/
    python3 tools/build_stage_backgrounds.py --preview DIR   # + podglądy złożonych etapów

Każdy etap bierze inny wycinek panoramy i własną korekcję barw (parametry na górze skryptu: `STAGES`).
`far1` + `far2` to jeden ciągły pas scenerii (250 px) rozcięty na dwie warstwy (`far1` ma `y_offset` -110
i tę samą paralaksę co `far2`). Szwy powtarzania poziomego są zamazane, kolory dopasowane do palety 256.

Żeby podmienić tło na docelowe, wystarczy wgrać własny plik o tej samej nazwie i rozmiarze do folderu etapu
(skrypt nadpisuje pliki tylko po ponownym uruchomieniu, więc nie uruchamiaj go po ręcznej podmianie).
