 


# ...existing code...
import cv2
import numpy as np
import sys
import time
import matplotlib.pyplot as plt
from IPython.display import display, clear_output
import os
from pathlib import Path
from datetime import datetime

# helper: try multiple backends to open camera index
def open_capture_with_fallback(index, backends=None, wait=0.1):
    """
    Попробовать открыть камеру index по очереди с разными бэкендами.
    Возвращает (cap, backend_name) или (None, None) если не удалось.
    """
    if backends is None:
        # собрать доступные константы OpenCV, порядок важен
        cand = []
        for name in ("CAP_DSHOW", "CAP_MSMF", "CAP_VFW", "CAP_ANY"):
            if hasattr(cv2, name):
                cand.append((getattr(cv2, name), name))
        # добавить вариант без явного бэкенда (cv2 сам выберет)
        cand.append((None, "default"))
    else:
        cand = backends

    for api, name in cand:
        try:
            if api is None:
                cap = cv2.VideoCapture(index)
            else:
                cap = cv2.VideoCapture(index, api)
            time.sleep(wait)
            if cap.isOpened():
                # дополнительная проверка чтения кадра — иногда isOpened True, но чтение ломается
                ret, _ = cap.read()
                if ret:
                    return cap, name
                else:
                    cap.release()
            else:
                cap.release()
        except Exception:
            try:
                cap.release()
            except Exception:
                pass
    return None, None

def combine_cameras_horizontal(idx_left=0, idx_right=1, width_each=640, height=480, backend=cv2.CAP_DSHOW,
                               force_w=1920, force_h=1080):
    """
    Открывает две камеры и показывает их поток в одном горизонтально объединённом окне.
    Принудительно пытается установить разрешение камер в force_w x force_h.
    Нажмите 'q' или ESC чтобы выйти. Нажмите пробел (Space) чтобы сохранить кадры
    (каждая камера — в отдельный файл).
    """
    is_notebook = 'ipykernel' in sys.modules

    # попытка открыть камеры с fallback по бэкендам
    capL, backendL = open_capture_with_fallback(idx_left)
    capR, backendR = open_capture_with_fallback(idx_right)

    if capL is None and capR is None:
        print(f"Ни одна из камер {idx_left}, {idx_right} не доступна")
        return

    if capL is not None:
        # попытка принудительно установить разрешение
        try:
            capL.set(cv2.CAP_PROP_FRAME_WIDTH, int(force_w))
            capL.set(cv2.CAP_PROP_FRAME_HEIGHT, int(force_h))
        except Exception:
            pass
    if capR is not None:
        try:
            capR.set(cv2.CAP_PROP_FRAME_WIDTH, int(force_w))
            capR.set(cv2.CAP_PROP_FRAME_HEIGHT, int(force_h))
        except Exception:
            pass

    # дать камерам время применить настройки
    time.sleep(0.2)

    def actual_size(cap):
        try:
            return int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        except Exception:
            return None, None

    wL, hL = actual_size(capL) if capL is not None else (None, None)
    wR, hR = actual_size(capR) if capR is not None else (None, None)

    if is_notebook:
        print("Running in notebook — frames will be shown inline (use Ctrl-C to stop).")
        if capL is not None:
            print(f"Cam {idx_left} opened with backend {backendL}, actual resolution: {wL}x{hL}")
        else:
            print(f"Cam {idx_left} not opened")
        if capR is not None:
            print(f"Cam {idx_right} opened with backend {backendR}, actual resolution: {wR}x{hR}")
        else:
            print(f"Cam {idx_right} not opened")
    else:
        win_name = f"Stereo {idx_left}-{idx_right}"
        cv2.namedWindow(win_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(win_name, width_each * 2, height)

    # base name
    base_name = "3dendo"
    try:
        if len(sys.argv) > 0 and sys.argv[0]:
            base_name = Path(sys.argv[0]).stem
    except Exception:
        pass
    try:
        base_name = Path(__file__).stem
    except Exception:
        pass

    def save_frame(frame, cam_idx):
        if frame is None:
            return
        h, w = frame.shape[:2]
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        fname = f"{base_name}_cam{cam_idx}_{ts}_{w}x{h}.png"
        try:
            ok = cv2.imwrite(fname, frame)
            if ok:
                print(f"Saved {fname}")
            else:
                print(f"Failed to save {fname}")
        except Exception as e:
            print(f"Error saving {fname}: {e}")

    try:
        while True:
            origL = origR = None
            disp_imgs = []

            # read left
            if capL is not None and capL.isOpened():
                retL, fL = capL.read()
                if not retL:
                    capL.release()
                    capL = None
                    fL = None
                else:
                    origL = fL.copy()
                    dispL = cv2.resize(fL, (width_each, height))
                    cv2.putText(dispL, f"Cam {idx_left}", (10, 30),
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (255,255,255), 2, cv2.LINE_AA)
                    disp_imgs.append(('L', dispL, idx_left, origL))

            # read right
            if capR is not None and capR.isOpened():
                retR, fR = capR.read()
                if not retR:
                    capR.release()
                    capR = None
                    fR = None
                else:
                    origR = fR.copy()
                    dispR = cv2.resize(fR, (width_each, height))
                    cv2.putText(dispR, f"Cam {idx_right}", (10, 30),
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (255,255,255), 2, cv2.LINE_AA)
                    disp_imgs.append(('R', dispR, idx_right, origR))

            if not disp_imgs:
                print("Кадры отсутствуют — выход")
                break

            ordered_disp = []
            ordered_orig = []
            for tag in ('L', 'R'):
                for t, disp_img, cam_idx, orig in disp_imgs:
                    if t == tag:
                        ordered_disp.append(disp_img)
                        ordered_orig.append((cam_idx, orig))
                        break

            combined = ordered_disp[0] if len(ordered_disp) == 1 else np.hstack(ordered_disp)

            if is_notebook:
                rgb = cv2.cvtColor(combined, cv2.COLOR_BGR2RGB)
                clear_output(wait=True)
                plt.figure(figsize=(combined.shape[1]/100, combined.shape[0]/100))
                plt.imshow(rgb)
                plt.axis('off')
                display(plt.gcf())
                plt.close()
                time.sleep(0.03)
            else:
                cv2.imshow(win_name, combined)
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q') or key == 27:
                    break
                if key == 32:  # space
                    # сохраняем оригиналы обеих камер (если есть)
                    for cam_idx, orig_frame in ordered_orig:
                        if orig_frame is not None:
                            save_frame(orig_frame, cam_idx)

    except KeyboardInterrupt:
        pass
    finally:
        try:
            if capL is not None and capL.isOpened(): capL.release()
        except Exception:
            pass
        try:
            if capR is not None and capR.isOpened(): capR.release()
        except Exception:
            pass
        if not is_notebook:
            cv2.destroyAllWindows()
# ...existing code...



# Пример
if __name__ == "__main__":
    combine_cameras_horizontal(1, 0)
# ...existing code...