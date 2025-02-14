;
;
;     Program written by Robert Livingston, 2023-04-24
;
;     QT:DRAWENVELOPE2 draws the vehicle envelope
;
;
(defun QT:DRAWENVELOPE2 (/ A ANGLIST AREA AREA0 BASELIST C C1 ENT ENT0 ENTSET ENTSET2 ENTSET3 LM:outline LM:ssboundingbox NODE OBJ P PA PB PC PD PLIST0 PLIST1 VLIST)
 ; LM:OUTLINE thanks to Lee Mac: http://www.lee-mac.com/outlineobjects.html
 (defun LM:outline ( sel / app are box cmd dis enl ent lst obj rtn tmp )
     (if (setq box (LM:ssboundingbox sel))
         (progn
             (setq app (vlax-get-acad-object)
                   dis (/ (apply 'distance box) 20.0)
                   lst (mapcar '(lambda ( a o ) (mapcar o a (list dis dis))) box '(- +))
                   are (apply '* (apply 'mapcar (cons '- (reverse lst))))
                   dis (* dis 1.5)
                   ent
                 (entmakex
                     (append
                        '(   (000 . "LWPOLYLINE")
                             (100 . "AcDbEntity")
                             (100 . "AcDbPolyline")
                             (090 . 4)
                             (070 . 1)
                         )
                         (mapcar '(lambda ( x ) (cons 10 (mapcar '(lambda ( y ) ((eval y) lst)) x)))
                            '(   (caar   cadar)
                                 (caadr  cadar)
                                 (caadr cadadr)
                                 (caar  cadadr)
                             )
                         )
                     )
                 )
             )
             (apply 'vlax-invoke
                 (vl-list* app 'zoomwindow
                     (mapcar '(lambda ( a o ) (mapcar o a (list dis dis 0.0))) box '(- +))
                 )
             )
             (setq cmd (getvar 'cmdecho)
                   enl (entlast)
                   rtn (ssadd)
             )
             (while (setq tmp (entnext enl)) (setq enl tmp))
             (setvar 'cmdecho 0)
             (command
                 "_.-boundary" "_a" "_b" "_n" sel ent "" "_i" "_y" "_o" "_p" "" "_non"
                 (trans (mapcar '- (car box) (list (/ dis 3.0) (/ dis 3.0))) 0 1) ""
             )
             (while (< 0 (getvar 'cmdactive)) (command ""))
             (entdel ent)
             (while (setq enl (entnext enl))
                 (if (and (vlax-property-available-p (setq obj (vlax-ename->vla-object enl)) 'area)
                          (equal (vla-get-area obj) are 1e-4)
                     )
                     (entdel enl)
                     (ssadd  enl rtn)
                 )
             )
             (vla-zoomprevious app)
             (setvar 'cmdecho cmd)
             rtn
         )
     )
 )
 (defun LM:ssboundingbox ( s / a b i m n o )
     (repeat (setq i (sslength s))
         (if
             (and
                 (setq o (vlax-ename->vla-object (ssname s (setq i (1- i)))))
                 (vlax-method-applicable-p o 'getboundingbox)
                 (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-getboundingbox (list o 'a 'b))))
             )
             (setq m (cons (vlax-safearray->list a) m)
                   n (cons (vlax-safearray->list b) n)
             )
         )
     )
     (if (and m n)
         (mapcar '(lambda ( a b ) (apply 'mapcar (cons a b))) '(min max) (list m n))
     )
 )
 (setq ENTSET (ssadd))
 (foreach NODE QTVLIST
  (progn
   (setq ENT (car NODE))
   (if (setq VLIST (QT:GETENVELOPE ENT))
    (progn
     (setq ANGLIST (cadr NODE))
     (setq BASELIST (caddr NODE))
     (setq C 0)
     (while (< C (length ANGLIST))
      (setq PLIST nil)
      (foreach P VLIST
       (setq PLIST (append PLIST (list (list (+ (nth 0 (nth C BASELIST)) (* (nth 0 P) (cos (nth C ANGLIST))) (* -1.0 (nth 1 P) (sin (nth C ANGLIST))))
                                             (+ (nth 1 (nth C BASELIST)) (* (nth 0 P) (sin (nth C ANGLIST))) (* (nth 1 P) (cos (nth C ANGLIST))))
                                       )
                                 )
                   )
       )
      )
      (setq ENTLIST (list (cons 0 "LWPOLYLINE")
                          (cons 100 "AcDbEntity")
                          (cons 100 "AcDbPolyline")
                          (cons 90 (length PLIST))
                          (cons 70 1)
                    )
      )
      (foreach P PLIST (setq ENTLIST (append ENTLIST (list (cons 10 P)))))
      (entmake ENTLIST)
      (ssadd (entlast) ENTSET)
      (setq C (1+ C))
     )
     (foreach P VLIST
      (setq ENTLIST (list (cons 0 "LWPOLYLINE")
                          (cons 100 "AcDbEntity")
                          (cons 100 "AcDbPolyline")
                          (cons 90 (length ANGLIST))
                          (cons 70 0)
                    )
      )
      (setq PLIST nil)
      (setq C 0)
      (while (< C (length ANGLIST))
       (setq PLIST (append PLIST (list (list (+ (nth 0 (nth C BASELIST)) (* (nth 0 P) (cos (nth C ANGLIST))) (* -1.0 (nth 1 P) (sin (nth C ANGLIST))))
                                             (+ (nth 1 (nth C BASELIST)) (* (nth 0 P) (sin (nth C ANGLIST))) (* (nth 1 P) (cos (nth C ANGLIST))))
                                       )
                                 )
                   )
       )
       (setq C (1+ C))
      )
      (foreach P PLIST (setq ENTLIST (append ENTLIST (list (cons 10 P)))))
      (entmake ENTLIST)
      (ssadd (entlast) ENTSET)
     )
    )
   )
  )
 )
 (if (> (sslength ENTSET) 0)
  (progn
   (setq ENTSET2 (LM:outline ENTSET))
   (command "._ERASE" ENTSET "")
   (setq C 0)
   (setq ENTSET3 (ssadd))
   (setq ENT0 nil)
   (setq AREA0 nil)
   (while (< C (sslength ENTSET2))
    (setq ENT (ssname ENTSET2 C))
    (if (vlax-property-available-p (setq OBJ (vlax-ename->vla-object ENT)) 'area)
     (if ENT0
      (progn
       (setq AREA (vla-get-area OBJ))
       (if (> AREA AREA0)
        (progn
         (ssadd ENT0 ENTSET3)
         (setq AREA0 AREA)
         (setq ENT0 ENT)
        )
        (progn
         (ssadd ENT ENTSET3)
        )
       )
      )
      (progn
       (setq ENT0 ENT)
       (setq AREA0 (vla-get-area OBJ))
      )
     )
     ;(ssadd ENT ENTSET3)
    )
    (setq C (1+ C))
   )
   (if (> (sslength ENTSET3) 0)
    (command "._ERASE" ENTSET3 "")
   )
  )
 )
)
