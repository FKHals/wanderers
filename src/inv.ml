
open Base
open Item

type t = {cnt: Cnt.t M.t; limit: int}

(* put an object obj into the container #ci *)
let put obj ci inv =
  if M.mem ci inv.cnt then
    let c = M.find ci inv.cnt in
    match Cnt.put obj c with
      Some c' -> Some {inv with cnt = M.add ci c' inv.cnt}
    | None -> None
  else
    None

(* try to put in any available container *)
let put_somewhere obj inv =
  let new_ci_c_opt =
    M.fold (fun ci c acc -> 
        match acc with 
          None -> 
            ( match Cnt.put obj c with 
                Some c' -> Some (ci, c') 
              | None -> None
            )
        | _ -> acc
      )
      inv.cnt None
  in
  match new_ci_c_opt with
    Some (ci,c) -> Some {inv with cnt = M.add ci c inv.cnt}
  | None -> None

(* get an object from the container #ci, slot si *)
let get ci si inv =
  if M.mem ci inv.cnt then
    let c = M.find ci inv.cnt in
    match Cnt.get si c with
      Some (obj, c') -> Some (obj, {inv with cnt = M.add ci c' inv.cnt})
    | None -> None
  else
    None

(* examine an object from the container #ci, slot si *)
let examine ci si inv =
  if M.mem ci inv.cnt then
    let c = M.find ci inv.cnt in
    Cnt.examine si c
  else
    None

let container ci inv =
  if M.mem ci inv.cnt then
    Some (M.find ci inv.cnt)
  else
    None

let fold f acc inv =
  M.fold (fun ci c acc -> 
      M.fold (fun si obj acc -> f acc ci si obj) c.Cnt.item acc
  ) inv.cnt acc

let decompose inv =
  fold (fun acc _ _ obj -> Resource.add acc (Item.decompose obj)) Resource.zero inv

let remove_everything inv =
  let cnt' =
    M.map (fun c -> Item.Cnt.remove_everything c) inv.cnt in
  {inv with cnt = cnt'}


let default = 
  {cnt = map_of_list [(0, Cnt.empty_nat_human); (1, Cnt.empty_unlimited)]; limit = 4}

let animal = 
  {cnt = M.empty; limit = 0}

let ground =
  {cnt = map_of_list [(0, Cnt.empty_unlimited)]; limit = 1}

(* function for optional ground inventories *)
let ground_drop obj optinv =
  let inv = 
    match optinv with
      Some inv -> inv
    | _ -> ground
  in
  match put_somewhere obj inv with
    Some inv' -> Some (Some inv')
  | None -> None

let ground_pickup ci ii optinv =
  match optinv with
  | Some ginv -> 
      ( match get ci ii ginv with
          Some (obj,ginv') -> 
            let upd_optinv = if M.is_empty ginv'.cnt then None else Some ginv' in
            Some (obj, upd_optinv)
        | None -> None )
  | _ -> None

let ground_drop_all invsrc optinv =
  let invdst = match optinv with
    Some inv -> inv
  | None -> ground
  in  
  let invleftovers = 
    {cnt = M.map (fun cnt -> Cnt.({item=M.empty; slot=cnt.slot; caplim=cnt.caplim})) invsrc.cnt; limit = invsrc.limit} in
  let cd = M.find 0 invdst.cnt in
  let invleft_final, cd_final =
    M.fold (fun ics cs (invleftovers, cd) -> 
        let cs1, cd1 = Cnt.put_all cs cd in
        ({invleftovers with cnt = M.add ics cs1 invleftovers.cnt}, cd1)
      ) invsrc.cnt (invleftovers, cd) in
  (invleft_final, Some ({invdst with cnt = M.add 0 cd_final invdst.cnt}))

