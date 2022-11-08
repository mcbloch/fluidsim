(ns src.sim
  (:require [lanterna.terminal :as t])
  (:import com.googlecode.lanterna.terminal.Terminal))

(def term (t/get-terminal :text)); :swing))
(def width 30)
(def height 40)
(def cursor_x (atom 2))
(def running (atom true))

(def world (atom (hash-map)))
(swap! world (fn [w] (assoc w {:x 2, :y 5} true)))

(defn add-particle [x y]
  (swap! world (fn [w] (assoc w {:x x, :y y} true))))
(defn move-particle [from-x from-y to-x to-y]
  (swap! world (fn [w] (dissoc w {:x from-x, :y from-y})))
  (swap! world (fn [w] (assoc w {:x to-x, :y to-y} true))))

(defn put-character [x y char]
  (t/put-character term char x y))

(defn draw-box []
  (doseq [y (range height)]
    (put-character 0 (+ y 1) \│))
  (doseq [x (range width)]
    (put-character (+ x 1) 0 \─))
  (doseq [y (range height)]
    (put-character (inc width) (+ y 1) \│))
  (doseq [x (range width)]
    (put-character (+ x 1) (inc height) \─))
  (put-character 0 0 \┌)
  (put-character (inc width) 0 \┐)
  (put-character (inc width) (inc height) \┘)
  (put-character 0 (inc height) \└))

(defn cursor-move-left []
  (when (> @cursor_x 0)
    (swap! cursor_x dec)))
(defn cursor-move-right []
  (when (< @cursor_x (dec width))
    (swap! cursor_x inc)))
(defn draw-cursor []
  (put-character (inc @cursor_x) 0 \▼))

(defn read-io []
  (let [key (t/get-key term)]
    (when-not (nil? key)
      (cond
        (= key \q) (do (t/stop term) (reset! running false))
        (= key :left) (cursor-move-left)
        (= key :right) (cursor-move-right)
        (= key \ ) (add-particle @cursor_x 0)
        :default (println "Do nothing"))
      (recur))))

(defn draw-particles []
  (doseq [[{x :x y :y} _value] @world]
    (put-character (inc x) (inc y) \x)))

(defn physics-step []
  (doseq [h (range (dec height))]
    (let [y (- (- height h) 2)]
      (doseq [x (range width)]
        (when (contains? @world {:x x :y y}) 
          (cond
            (not (contains? @world {:x x :y (inc y)})) (move-particle x y x (inc y))
            (and 
             (> x 0)
             (not (contains? @world {:x (dec x) :y (inc y)}))) (move-particle x y (dec x) (inc y)) 
            (and 
             (< x (dec width))
             (not (contains? @world {:x (inc x) :y (inc y)}))) (move-particle x y (inc x) (inc y))))))))

(defn run []
  (t/start term)
  (.setCursorVisible term false)
  (while @running 
    (read-io)
    (physics-step)
    (t/clear term)
    (draw-box)
    (draw-cursor)
    (draw-particles)
    (Thread/sleep 16)))

(run)