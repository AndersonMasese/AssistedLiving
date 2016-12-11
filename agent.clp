;// AGENT


(defmodule AGENT (import MAIN ?ALL))


;//_______Templates
(deftemplate K-cell  (slot pos-r) (slot pos-c) (slot contains))

(deftemplate K-agent
	(slot step)
	(slot time) 
	(slot pos-r) 
	(slot pos-c) 
	(slot direction) 
	(multislot content)
        (slot free)
        (slot waste)
)

(deftemplate goal-pos (slot id) (slot pos-r) (slot pos-c))
(deftemplate goal-achieve (slot status))
(deftemplate path-to-goal (slot id) (slot pos-r) (slot pos-c) (slot direction))
(deftemplate go-direction (slot step) (slot direction))

;//_______Functions

; Funzione che restituisce "come muoversi" o "dove girarsi" per passare da una direzione
; all'altra. Dir1 è in genere la direzione dell'agente, dir2 quella desiderata. 
; restituisce left, right, same (se si è già allineati) e opposite (se le due direzioni sono opposte e non ha importanza dove girarsi)
(deffunction turn (?dir1 ?dir2) 
	(switch ?dir1
		(case north then 
			(switch ?dir2
				(case north then same)
				(case south then opposite)
				(case west then left)
				(case east then right)
			) 
		)
		(case south then
			(switch ?dir2
				(case north then opposite)
				(case south then same)
				(case west then right)
				(case east then left)
			) 
		)
		(case west then 
			(switch ?dir2
				(case north then right)
				(case south then left)
				(case west then same)
				(case east then opposite)
			) 
		)
		(case east then 
			(switch ?dir2
				(case north then left)
				(case south then right)
				(case west then opposite)
				(case east then same)
			) 
		)
	)

)

;//_______Rules

(defrule  beginagent1
    (declare (salience 11))
    (status (step 0))
    (not (exec (step 0)))
    (prior-cell (pos-r ?r) (pos-c ?c) (contains ?x)) 
	=>
	(assert (K-cell (pos-r ?r) (pos-c ?c) (contains ?x)))
)

(defrule  beginagent2
      (declare (salience 10))
      (status (step 0))
      (not (exec (step 0)))
      (K-cell (pos-r ?r) (pos-c ?c) (contains Parking))  
	  =>
     (assert (K-agent (time 0) (step 0) (pos-r ?r) (pos-c ?c) (direction north) (free 2) (waste no)))
	 ;linee aggiunte rispetto al codice originale, per provare il cammino verso un goal
	 (assert (goal-pos (id 1) (pos-r 2) (pos-c 2)))
	 (assert (goal-achieve (status false)))
)

(defrule goal_pos_achieved 
	(declare (salience 10))
	(goal-pos (id ?i) (pos-r ?x) (pos-c ?y))
	(K-agent (pos-r ?x) (pos-c ?y))
	=>
	(assert (goal-achieve (status true)))
	(printout t "goal achieved, good job")
)

; A seconda di goal-pos, asserisce fatti di tipo "go-direction" per capire in che direzione deve andare
(defrule get_direction
	(declare (salience 9))
	(goal-pos (pos-r ?x) (pos-c ?y))
	(K-agent (step ?s) (pos-r ?r) (pos-c ?c))
	=>
	(if (> ?x ?r)
		then (assert (go-direction (step ?s) (direction north))) )
	(if (> ?r ?x)
		then (assert (go-direction (step ?s) (direction south))))
	(if (> ?c ?y) 
		then (assert (go-direction (step ?s) (direction west))))
	(if (> ?y ?c) 
		then (assert (go-direction (step ?s) (direction east))))
	
)

; Questa regola cerca delle K-cell vuote che siano nella stessa direzione di go-direction
(defrule get_path_to_goal 
	(declare (salience 8))
	(goal-pos (id ?i) (pos-r ?x) (pos-c ?y))
	(K-agent (pos-r ?rA) (pos-c ?cA))
	(K-cell (pos-r ?r1) (pos-c ?c1) (contains Empty))
	(go-direction (direction ?where))
	(test (or 
			(and (= ?r1 (- ?rA 1)) (= ?c1 ?cA) (not(neq ?where south)))
			(and (= ?r1 (+ ?rA 1)) (= ?c1 ?cA) (not(neq ?where north)))
			(and (= ?c1 (- ?cA 1)) (= ?r1 ?rA) (not(neq ?where west)))
			(and (= ?c1 (+ ?cA 1)) (= ?r1 ?rA) (not(neq ?where east)))
	))
	=>
	(printout t "found something")
	(printout t crlf crlf)
	(assert (path-to-goal (id ?i) (pos-r ?r1) (pos-c ?c1) (direction ?where)))
)
	
; Ho stabilito che al primo step l'azione sia una wait, per avere le percezioni	
(defrule ask_act_0	
 ?f <-   (status (step 0))
    =>  (printout t crlf crlf)
        (printout t "first action: wait to get perceptions")
        (printout t crlf crlf)
        (modify ?f (work on))		
		(assert (exec (step 0) (action Wait)))
			
		)

; Regola che cerca di direzionare l'agente verso il path-to-goal precedentemente deciso
; da riscrivere		
(defrule get_to_path 
	(declare (salience 7))
	(status (step ?s))
	?f <-(path-to-goal (id ?i) (pos-r ?r1) (pos-c ?c1) (direction ?d))
	(K-agent (direction ?dA))
	=>
	(if (not (neq ?dA ?d))
		then
		(assert (exec (step ?s) (action Forward)))
		(printout t "go on " ?s)
		else
		(assert (exec (step ?s) (action Turnright)))
		(printout t "turn" ?i)
	)
	(printout t crlf crlf)
	(retract ?f)	
)		

;(defrule update_cells 
;	(declare (salience 11))
;	(perc-vision (step ?s) (pos-r ?r) (pos-c ?c) (direction ?d))
;	(status (step ?s1))	
;	?f <-(K-cell (pos-r ?r1) (pos-c ?c1) (contains ?x))
	;Il test seleziona solo le k-cell che siano nel quadrato attorno alla posizione del robot
;	(test (or			
;			(and (= ?r1 (- ?r 1)) (= ?c1 (+ ?c 1)))
;			(and (= ?r1 (- ?r 1)) (= ?c1 ?c))
;			(and (= ?r1 (- ?r 1)) (= ?c1 (- ?c 1)))
;			(and (= ?r1 ?r) (= ?c1 (+ ?c 1)))
;			(and (= ?r1 ?r) (= ?c1 ?c))
;			(and (= ?r1 ?r) (= ?c1 (- ?c 1)))
;			(and (= ?r1 (- ?r 1)) (= ?c1 (+ ?c 1)))
;			(and (= ?r1 (- ?r 1)) (= ?c1 ?c))			
;			(and (= ?r1 (- ?r 1)) (= ?c1 (- ?c 1)))
;			)
	;il test serve a essere sicuri di prendere la perc-vision attuale (l'ultima registrata)		
;	(test (= ?s1 ?s))
;	=>		
;	(assert )	
;)
	
; Fa l'update del fatto K-agent in base alle percezioni ricevute e ritira quello dello step precedente
(defrule update_agent 
	(declare (salience 12))
	(perc-vision (step ?s) (pos-r ?r) (pos-c ?c) (direction ?d))
	?f <- (K-agent (step ?sA) (free ?fr) (waste ?w))
	(test (< ?sA ?s))
	=>
	(assert (K-agent (time 0) (step ?s) (pos-r ?r) (pos-c ?c) (direction ?d) (free ?fr) (waste ?w)))
	(retract ?f)
)

; Ritira i fatti go-direction dello step precedente
(defrule retract_prev_directions 
	(declare (salience 11))	
	(perc-vision (step ?s) (pos-r ?r) (pos-c ?c) (direction ?d))
	?f <- (go-direction (step ?sgd) (direction ?any))	
	(test (< ?sgd ?s))
	=>
	(retract ?f)
)
	
(defrule ask_act
 ?f <-   (status (step ?i))
 (not (status (step 0)))
    =>  (printout t crlf crlf)
        (printout t "action to be executed at step:" ?i)
        (printout t crlf crlf)
        (modify ?f (work on))			
		)



(defrule exec_act
    (status (step ?i))
    (exec (step ?i))
 => (focus MAIN))