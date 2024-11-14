use std::ffi::{c_char, CString};

use affine_native::hashcash::Stamp;

#[no_mangle]
pub extern "C" fn hashcash_mint(
  resource: *const c_char,
  length: usize,
  bits: u32,
) -> *const c_char {
  let hash = Stamp::mint(
    unsafe { String::from_raw_parts(resource.cast_mut().cast(), length, length) },
    Some(bits),
  )
  .format();

  let c_str = CString::new(hash).expect("String should be valid");
  c_str.into_raw()
}
