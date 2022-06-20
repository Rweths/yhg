open OUnit

let test_max_buffers () =
  let buffer_pool = BufferPool.create ~pool_size:1000 ~buffer_size:100 in
  let max_buffers = BufferPool.max_buffers buffer_pool in
  assert_equal ~printer:string_of_int 10 max_buffers

let test_max_buffers_remainder () =
  let buffer_pool = BufferPool.create ~pool_size:950 ~buffer_size:100 in
  let max_buffers = BufferPool.max_buffers buffer_pool in
  assert_equal ~printer:string_of_int 10 max_buffers

let test_acquire_buffer () =
  let buffer_pool = BufferPool.create ~pool_size:10 ~buffer_size:10 in
  let mutex = Mutex.create () in
  let condition = Condition.create () in
  Utils.with_lock mutex (fun () ->
      let buffer = BufferPool.acquire_buffer mutex condition buffer_pool in
      buffer.BufferPool.Buffer.arr.{0} <- 'a';
      BufferPool.release_buffer buffer condition buffer_pool;
      let buffer' = BufferPool.acquire_buffer mutex condition buffer_pool in
      assert_equal ~printer:Std.string_of_char 'a'
        buffer'.BufferPool.Buffer.arr.{0})

let test_pending_requests () =
  let flag = ref false in
  let buffer_pool = BufferPool.create ~pool_size:10 ~buffer_size:10 in
  let mutex = Mutex.create () in
  let condition = Condition.create () in
  Mutex.lock mutex;
  let buffer = BufferPool.acquire_buffer mutex condition buffer_pool in
  assert_equal ~printer:string_of_int 0
    (BufferPool.pending_requests buffer_pool);
  buffer.BufferPool.Buffer.arr.{0} <- 'b';
  Mutex.unlock mutex;
  let thread =
    Thread.create
      (fun () ->
        Utils.with_lock mutex (fun () ->
            let b = BufferPool.acquire_buffer mutex condition buffer_pool in
            flag := b.BufferPool.Buffer.arr.{0} = 'a'))
      ()
  in
  Thread.delay 0.05;
  assert_equal ~printer:string_of_int 1
    (BufferPool.pending_requests buffer_pool);
  buffer.BufferPool.Buffer.arr.{0} <- 'a';
  Mutex.lock mutex;
  BufferPool.release_buffer buffer condition buffer_pool;
  Mutex.unlock mutex;
  Thread.join thread;
  assert_equal ~printer:string_of_int 0
    (BufferPool.pending_requests buffer_pool);
  assert_equal ~printer:string_of_bool true !flag

let suite =
  "Buffer pool test"
  >::: [
         "test_max_buffers" >:: test_max_buffers;
         "test_max_buffers_remainder" >:: test_max_buffers_remainder;
         "test_acquire_buffer" >:: test_acquire_buffer;
         "test_pending_requests" >:: test_pending_requests;
       ]
