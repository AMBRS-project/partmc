! Copyright (C) 2007-2011 Matthew West
! Licensed under the GNU General Public License version 2 or (at your
! option) any later version. See the file COPYING for details.

!> \file
!> The pmc_mpi module.

!> Wrapper functions for MPI.
!!
!! All of these functions can be called irrespective of whether MPI
!! support was compiled in or not. If MPI support is not enabled then
!! they do the obvious trivial thing (normally nothing).
module pmc_mpi

  use pmc_util
  
#ifdef PMC_USE_MPI
  use mpi
#endif

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Whether MPI support is compiled in.
  logical function pmc_mpi_support()

#ifdef PMC_USE_MPI
    pmc_mpi_support = .true.
#else
    pmc_mpi_support = .false.
#endif

  end function pmc_mpi_support

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Dies if \c ierr is not ok.
  subroutine pmc_mpi_check_ierr(ierr)

    !> MPI status code.
    integer, intent(in) :: ierr

#ifdef PMC_USE_MPI
    if (ierr /= MPI_SUCCESS) then
       call pmc_mpi_abort(1)
    end if
#endif

  end subroutine pmc_mpi_check_ierr

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Initialize MPI.
  subroutine pmc_mpi_init()

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_init(ierr)
    call pmc_mpi_check_ierr(ierr)
    call pmc_mpi_test()
#endif

  end subroutine pmc_mpi_init

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Abort the program.
  subroutine pmc_mpi_abort(status)

    !> Status flag to abort with.
    integer, intent(in) :: status

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_abort(MPI_COMM_WORLD, status, ierr)
#else
    call die(status)
#endif

  end subroutine pmc_mpi_abort

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Shut down MPI.
  subroutine pmc_mpi_finalize()

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_finalize(ierr)
    call pmc_mpi_check_ierr(ierr)
#endif

  end subroutine pmc_mpi_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Synchronize all processors.
  subroutine pmc_mpi_barrier()

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_barrier(MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
#endif

  end subroutine pmc_mpi_barrier

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the rank of the current process.
  integer function pmc_mpi_rank()

#ifdef PMC_USE_MPI
    integer :: rank, ierr

    call mpi_comm_rank(MPI_COMM_WORLD, rank, ierr)
    call pmc_mpi_check_ierr(ierr)
    pmc_mpi_rank = rank
#else
    pmc_mpi_rank = 0
#endif

  end function pmc_mpi_rank

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns the total number of processes.
  integer function pmc_mpi_size()

#ifdef PMC_USE_MPI
    integer :: size, ierr

    call mpi_comm_size(MPI_COMM_WORLD, size, ierr)
    call pmc_mpi_check_ierr(ierr)
    pmc_mpi_size = size
#else
    pmc_mpi_size = 1
#endif

  end function pmc_mpi_size

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Perform basic sanity checks on send/receive.
  subroutine pmc_mpi_test()

#ifdef PMC_USE_MPI
    real(kind=dp), parameter :: test_real = 2.718281828459d0
    complex(kind=dc), parameter :: test_complex &
         = (0.707106781187d0, 1.4142135624d0)
    logical, parameter :: test_logical = .true.
    character(len=100), parameter :: test_string &
         = "a truth universally acknowledged"
    integer, parameter :: test_integer = 314159

    character, allocatable :: buffer(:)
    integer :: buffer_size, max_buffer_size, position
    real(kind=dp) :: send_real, recv_real
    complex(kind=dc) :: send_complex, recv_complex
    logical :: send_logical, recv_logical
    character(len=100) :: send_string, recv_string
    integer :: send_integer, recv_integer
    real(kind=dp) :: send_real_array(2)
    real(kind=dp), pointer :: recv_real_array(:)

    allocate(recv_real_array(1))

    if (pmc_mpi_rank() == 0) then
       send_real = test_real
       send_complex = test_complex
       send_logical = test_logical
       send_string = test_string
       send_integer = test_integer
       send_real_array(1) = real(test_complex)
       send_real_array(2) = aimag(test_complex)

       max_buffer_size = 0
       max_buffer_size = max_buffer_size &
            + pmc_mpi_pack_size_integer(send_integer)
       max_buffer_size = max_buffer_size &
            + pmc_mpi_pack_size_real(send_real)
       max_buffer_size = max_buffer_size &
            + pmc_mpi_pack_size_complex(send_complex)
       max_buffer_size = max_buffer_size &
            + pmc_mpi_pack_size_logical(send_logical)
       max_buffer_size = max_buffer_size &
            + pmc_mpi_pack_size_string(send_string)
       max_buffer_size = max_buffer_size &
            + pmc_mpi_pack_size_real_array(send_real_array)

       allocate(buffer(max_buffer_size))

       position = 0
       call pmc_mpi_pack_real(buffer, position, send_real)
       call pmc_mpi_pack_complex(buffer, position, send_complex)
       call pmc_mpi_pack_logical(buffer, position, send_logical)
       call pmc_mpi_pack_string(buffer, position, send_string)
       call pmc_mpi_pack_integer(buffer, position, send_integer)
       call pmc_mpi_pack_real_array(buffer, position, send_real_array)
       call assert_msg(350740830, position <= max_buffer_size, &
            "MPI test failure: pack position " &
            // trim(integer_to_string(position)) &
            // " greater than max_buffer_size " &
            // trim(integer_to_string(max_buffer_size)))
       buffer_size = position ! might be less than we allocated
    end if

    call pmc_mpi_bcast_integer(buffer_size)

    if (pmc_mpi_rank() /= 0) then
       allocate(buffer(buffer_size))
    end if

    call pmc_mpi_bcast_packed(buffer)

    if (pmc_mpi_rank() /= 0) then
       position = 0
       call pmc_mpi_unpack_real(buffer, position, recv_real)
       call pmc_mpi_unpack_complex(buffer, position, recv_complex)
       call pmc_mpi_unpack_logical(buffer, position, recv_logical)
       call pmc_mpi_unpack_string(buffer, position, recv_string)
       call pmc_mpi_unpack_integer(buffer, position, recv_integer)
       call pmc_mpi_unpack_real_array(buffer, position, recv_real_array)
       call assert_msg(787677020, position == buffer_size, &
            "MPI test failure: unpack position " &
            // trim(integer_to_string(position)) &
            // " not equal to buffer_size " &
            // trim(integer_to_string(buffer_size)))
    end if

    deallocate(buffer)

    if (pmc_mpi_rank() /= 0) then
       call assert_msg(567548916, recv_real == test_real, &
            "MPI test failure: real recv " &
            // trim(real_to_string(recv_real)) &
            // " not equal to " &
            // trim(real_to_string(test_real)))
       call assert_msg(653908509, recv_complex == test_complex, &
            "MPI test failure: complex recv " &
            // trim(complex_to_string(recv_complex)) &
            // " not equal to " &
            // trim(complex_to_string(test_complex)))
       call assert_msg(307746296, recv_logical .eqv. test_logical, &
            "MPI test failure: logical recv " &
            // trim(logical_to_string(recv_logical)) &
            // " not equal to " &
            // trim(logical_to_string(test_logical)))
       call assert_msg(155693492, recv_string == test_string, &
            "MPI test failure: string recv '" &
            // trim(recv_string) &
            // "' not equal to '" &
            // trim(test_string) // "'")
       call assert_msg(875699427, recv_integer == test_integer, &
            "MPI test failure: integer recv " &
            // trim(integer_to_string(recv_integer)) &
            // " not equal to " &
            // trim(integer_to_string(test_integer)))
       call assert_msg(326982363, size(recv_real_array) == 2, &
            "MPI test failure: real array recv size " &
            // trim(integer_to_string(size(recv_real_array))) &
            // " not equal to 2")
       call assert_msg(744394323, &
            recv_real_array(1) == real(test_complex), &
            "MPI test failure: real array recv index 1 " &
            // trim(real_to_string(recv_real_array(1))) &
            // " not equal to " &
            // trim(real_to_string(real(test_complex))))
       call assert_msg(858902527, &
            recv_real_array(2) == aimag(test_complex), &
            "MPI test failure: real array recv index 2 " &
            // trim(real_to_string(recv_real_array(2))) &
            // " not equal to " &
            // trim(real_to_string(aimag(test_complex))))
    end if

    deallocate(recv_real_array)
#endif

  end subroutine pmc_mpi_test

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Broadcast the given value from process 0 to all other processes.
  subroutine pmc_mpi_bcast_integer(val)

    !> Value to broadcast.
    integer, intent(inout) :: val

#ifdef PMC_USE_MPI
    integer :: root, ierr

    root = 0 ! source of data to broadcast
    call mpi_bcast(val, 1, MPI_INTEGER, root, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
#endif

  end subroutine pmc_mpi_bcast_integer

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Broadcast the given value from process 0 to all other processes.
  subroutine pmc_mpi_bcast_string(val)

    !> Value to broadcast.
    character(len=*), intent(inout) :: val

#ifdef PMC_USE_MPI
    integer :: root, ierr

    root = 0 ! source of data to broadcast
    call mpi_bcast(val, len(val), MPI_CHARACTER, root, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
#endif

  end subroutine pmc_mpi_bcast_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Broadcast the given value from process 0 to all other processes.
  subroutine pmc_mpi_bcast_packed(val)

    !> Value to broadcast.
    character, intent(inout) :: val(:)

#ifdef PMC_USE_MPI
    integer :: root, ierr

    root = 0 ! source of data to broadcast
    call mpi_bcast(val, size(val), MPI_CHARACTER, root, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
#endif

  end subroutine pmc_mpi_bcast_packed

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_integer(val)

    !> Value to pack.
    integer, intent(in) :: val

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(1, MPI_INTEGER, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_integer, ierr)
    call pmc_mpi_check_ierr(ierr)
#else
    pmc_mpi_pack_size_integer = 0
#endif

  end function pmc_mpi_pack_size_integer

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_real(val)

    !> Value to pack.
    real(kind=dp), intent(in) :: val

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(1, MPI_DOUBLE_PRECISION, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_real, ierr)
    call pmc_mpi_check_ierr(ierr)
#else
    pmc_mpi_pack_size_real = 0
#endif

  end function pmc_mpi_pack_size_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_string(val)

    !> Value to pack.
    character(len=*), intent(in) :: val

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(len_trim(val), MPI_CHARACTER, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_string, ierr)
    call pmc_mpi_check_ierr(ierr)
    pmc_mpi_pack_size_string = pmc_mpi_pack_size_string &
         + pmc_mpi_pack_size_integer(len_trim(val))
#else
    pmc_mpi_pack_size_string = 0
#endif

  end function pmc_mpi_pack_size_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_logical(val)

    !> Value to pack.
    logical, intent(in) :: val

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(1, MPI_LOGICAL, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_logical, ierr)
    call pmc_mpi_check_ierr(ierr)
#else
    pmc_mpi_pack_size_logical = 0
#endif

  end function pmc_mpi_pack_size_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_complex(val)

    !> Value to pack.
    complex(kind=dc), intent(in) :: val

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(1, MPI_DOUBLE_COMPLEX, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_complex, ierr)
    call pmc_mpi_check_ierr(ierr)
#else
    pmc_mpi_pack_size_complex = 0
#endif

  end function pmc_mpi_pack_size_complex

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_integer_array(val)

    !> Value to pack.
    integer, intent(in) :: val(:)

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(size(val), MPI_INTEGER, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_integer_array, ierr)
    call pmc_mpi_check_ierr(ierr)
    pmc_mpi_pack_size_integer_array = pmc_mpi_pack_size_integer_array &
         + pmc_mpi_pack_size_integer(size(val))
#else
    pmc_mpi_pack_size_integer_array = 0
#endif

  end function pmc_mpi_pack_size_integer_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_real_array(val)

    !> Value to pack.
    real(kind=dp), intent(in) :: val(:)

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(size(val), MPI_DOUBLE_PRECISION, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_real_array, ierr)
    call pmc_mpi_check_ierr(ierr)
    pmc_mpi_pack_size_real_array = pmc_mpi_pack_size_real_array &
         + pmc_mpi_pack_size_integer(size(val))
#else
    pmc_mpi_pack_size_real_array = 0
#endif

  end function pmc_mpi_pack_size_real_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_string_array(val)

    !> Value to pack.
    character(len=*), intent(in) :: val(:)

    integer :: i, total_size

    total_size = pmc_mpi_pack_size_integer(size(val))
    do i = 1,size(val)
       total_size = total_size + pmc_mpi_pack_size_string(val(i))
    end do
    pmc_mpi_pack_size_string_array = total_size

  end function pmc_mpi_pack_size_string_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Determines the number of bytes required to pack the given value.
  integer function pmc_mpi_pack_size_real_array_2d(val)

    !> Value to pack.
    real(kind=dp), intent(in) :: val(:,:)

    integer :: ierr

#ifdef PMC_USE_MPI
    call mpi_pack_size(size(val), MPI_DOUBLE_PRECISION, MPI_COMM_WORLD, &
         pmc_mpi_pack_size_real_array_2d, ierr)
    call pmc_mpi_check_ierr(ierr)
    pmc_mpi_pack_size_real_array_2d = pmc_mpi_pack_size_real_array_2d &
         + pmc_mpi_pack_size_integer(size(val,1)) &
         + pmc_mpi_pack_size_integer(size(val,2))
#else
    pmc_mpi_pack_size_real_array_2d = 0
#endif

  end function pmc_mpi_pack_size_real_array_2d

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_integer(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    integer, intent(in) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_pack(val, 1, MPI_INTEGER, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(913495993, &
         position - prev_position <= pmc_mpi_pack_size_integer(val))
#endif

  end subroutine pmc_mpi_pack_integer

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_real(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    real(kind=dp), intent(in) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_pack(val, 1, MPI_DOUBLE_PRECISION, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(395354132, &
         position - prev_position <= pmc_mpi_pack_size_real(val))
#endif

  end subroutine pmc_mpi_pack_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_string(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    character(len=*), intent(in) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, length, ierr

    prev_position = position
    length = len_trim(val)
    call pmc_mpi_pack_integer(buffer, position, length)
    call mpi_pack(val, length, MPI_CHARACTER, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(607212018, &
         position - prev_position <= pmc_mpi_pack_size_string(val))
#endif

  end subroutine pmc_mpi_pack_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_logical(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    logical, intent(in) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_pack(val, 1, MPI_LOGICAL, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(104535200, &
         position - prev_position <= pmc_mpi_pack_size_logical(val))
#endif

  end subroutine pmc_mpi_pack_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_complex(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    complex(kind=dc), intent(in) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_pack(val, 1, MPI_DOUBLE_COMPLEX, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(640416372, &
         position - prev_position <= pmc_mpi_pack_size_complex(val))
#endif

  end subroutine pmc_mpi_pack_complex

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_integer_array(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    integer, intent(in) :: val(:)

#ifdef PMC_USE_MPI
    integer :: prev_position, n, ierr

    prev_position = position
    n = size(val)
    call pmc_mpi_pack_integer(buffer, position, n)
    call mpi_pack(val, n, MPI_INTEGER, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(698601296, &
         position - prev_position <= pmc_mpi_pack_size_integer_array(val))
#endif

  end subroutine pmc_mpi_pack_integer_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_real_array(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    real(kind=dp), intent(in) :: val(:)

#ifdef PMC_USE_MPI
    integer :: prev_position, n, ierr

    prev_position = position
    n = size(val)
    call pmc_mpi_pack_integer(buffer, position, n)
    call mpi_pack(val, n, MPI_DOUBLE_PRECISION, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(825718791, &
         position - prev_position <= pmc_mpi_pack_size_real_array(val))
#endif

  end subroutine pmc_mpi_pack_real_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_string_array(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    character(len=*), intent(in) :: val(:)

#ifdef PMC_USE_MPI
    integer :: prev_position, i, n

    prev_position = position
    n = size(val)
    call pmc_mpi_pack_integer(buffer, position, n)
    do i = 1,n
       call pmc_mpi_pack_string(buffer, position, val(i))
    end do
    call assert(630900704, &
         position - prev_position <= pmc_mpi_pack_size_string_array(val))
#endif

  end subroutine pmc_mpi_pack_string_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Packs the given value into the buffer, advancing position.
  subroutine pmc_mpi_pack_real_array_2d(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    real(kind=dp), intent(in) :: val(:,:)

#ifdef PMC_USE_MPI
    integer :: prev_position, n1, n2, ierr

    prev_position = position
    n1 = size(val, 1)
    n2 = size(val, 2)
    call pmc_mpi_pack_integer(buffer, position, n1)
    call pmc_mpi_pack_integer(buffer, position, n2)
    call mpi_pack(val, n1*n2, MPI_DOUBLE_PRECISION, buffer, size(buffer), &
         position, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(567349745, &
         position - prev_position <= pmc_mpi_pack_size_real_array_2d(val))
#endif

  end subroutine pmc_mpi_pack_real_array_2d

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_integer(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    integer, intent(out) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_unpack(buffer, size(buffer), position, val, 1, MPI_INTEGER, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(890243339, &
         position - prev_position <= pmc_mpi_pack_size_integer(val))
#endif

  end subroutine pmc_mpi_unpack_integer

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_real(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    real(kind=dp), intent(out) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_unpack(buffer, size(buffer), position, val, 1, &
         MPI_DOUBLE_PRECISION, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(570771632, &
         position - prev_position <= pmc_mpi_pack_size_real(val))
#endif

  end subroutine pmc_mpi_unpack_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_string(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    character(len=*), intent(out) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, length, ierr

    prev_position = position
    call pmc_mpi_unpack_integer(buffer, position, length)
    call assert(946399479, length <= len(val))
    val = ''
    call mpi_unpack(buffer, size(buffer), position, val, length, &
         MPI_CHARACTER, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(503378058, &
         position - prev_position <= pmc_mpi_pack_size_string(val))
#endif

  end subroutine pmc_mpi_unpack_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_logical(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    logical, intent(out) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_unpack(buffer, size(buffer), position, val, 1, MPI_LOGICAL, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(694750528, &
         position - prev_position <= pmc_mpi_pack_size_logical(val))
#endif

  end subroutine pmc_mpi_unpack_logical

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_complex(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    complex(kind=dc), intent(out) :: val

#ifdef PMC_USE_MPI
    integer :: prev_position, ierr

    prev_position = position
    call mpi_unpack(buffer, size(buffer), position, val, 1, &
         MPI_DOUBLE_COMPLEX, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(969672634, &
         position - prev_position <= pmc_mpi_pack_size_complex(val))
#endif

  end subroutine pmc_mpi_unpack_complex

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_integer_array(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    integer, pointer :: val(:)

#ifdef PMC_USE_MPI
    integer :: prev_position, n, ierr

    prev_position = position
    call pmc_mpi_unpack_integer(buffer, position, n)
    deallocate(val)
    allocate(val(n))
    call mpi_unpack(buffer, size(buffer), position, val, n, MPI_INTEGER, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(565840919, &
         position - prev_position <= pmc_mpi_pack_size_integer_array(val))
#endif

  end subroutine pmc_mpi_unpack_integer_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_real_array(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    real(kind=dp), pointer :: val(:)

#ifdef PMC_USE_MPI
    integer :: prev_position, n, ierr

    prev_position = position
    call pmc_mpi_unpack_integer(buffer, position, n)
    deallocate(val)
    allocate(val(n))
    call mpi_unpack(buffer, size(buffer), position, val, n, &
         MPI_DOUBLE_PRECISION, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(782875761, &
         position - prev_position <= pmc_mpi_pack_size_real_array(val))
#endif

  end subroutine pmc_mpi_unpack_real_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_string_array(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    character(len=*), pointer :: val(:)

#ifdef PMC_USE_MPI
    integer :: prev_position, i, n

    prev_position = position
    call pmc_mpi_unpack_integer(buffer, position, n)
    deallocate(val)
    allocate(val(n))
    do i = 1,n
       call pmc_mpi_unpack_string(buffer, position, val(i))
    end do
    call assert(320065648, &
         position - prev_position <= pmc_mpi_pack_size_string_array(val))
#endif

  end subroutine pmc_mpi_unpack_string_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Unpacks the given value from the buffer, advancing position.
  subroutine pmc_mpi_unpack_real_array_2d(buffer, position, val)

    !> Memory buffer.
    character, intent(inout) :: buffer(:)
    !> Current buffer position.
    integer, intent(inout) :: position
    !> Value to pack.
    real(kind=dp), pointer :: val(:,:)

#ifdef PMC_USE_MPI
    integer :: prev_position, n1, n2, ierr

    prev_position = position
    call pmc_mpi_unpack_integer(buffer, position, n1)
    call pmc_mpi_unpack_integer(buffer, position, n2)
    deallocate(val)
    allocate(val(n1,n2))
    call mpi_unpack(buffer, size(buffer), position, val, n1*n2, &
         MPI_DOUBLE_PRECISION, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    call assert(781681739, position - prev_position &
         <= pmc_mpi_pack_size_real_array_2d(val))
#endif

  end subroutine pmc_mpi_unpack_real_array_2d

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Computes the average of val across all processes, storing the
  !> result in val_avg on the root process.
  subroutine pmc_mpi_reduce_avg_real(val, val_avg)

    !> Value to average.
    real(kind=dp), intent(in) :: val
    !> Result.
    real(kind=dp), intent(out) :: val_avg

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_reduce(val, val_avg, 1, MPI_DOUBLE_PRECISION, MPI_SUM, 0, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    if (pmc_mpi_rank() == 0) then
       val_avg = val_avg / real(pmc_mpi_size(), kind=dp)
    end if
#else
    val_avg = val
#endif

  end subroutine pmc_mpi_reduce_avg_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Transfer the value between the given processors.
  subroutine pmc_mpi_transfer_real(from_val, to_val, from_proc, to_proc)

    !> Value to send.
    real(kind=dp), intent(in) :: from_val
    !> Variable to send to.
    real(kind=dp), intent(out) :: to_val
    !> Processor to send from.
    integer, intent(in) :: from_proc
    !> Processor to send to.
    integer, intent(in) :: to_proc

#ifdef PMC_USE_MPI
    integer :: rank, ierr, status(MPI_STATUS_SIZE)

    rank = pmc_mpi_rank()
    if (from_proc == to_proc) then
       if (rank == from_proc) then
          to_val = from_val
       end if
    else
       if (rank == from_proc) then
          call mpi_send(from_val, 1, MPI_DOUBLE_PRECISION, to_proc, &
               208020430, MPI_COMM_WORLD, ierr)
          call pmc_mpi_check_ierr(ierr)
       elseif (rank == to_proc) then
          call mpi_recv(to_val, 1, MPI_DOUBLE_PRECISION, from_proc, &
               208020430, MPI_COMM_WORLD, status, ierr)
          call pmc_mpi_check_ierr(ierr)
       end if
    end if
#else
    to_val = from_val
#endif

  end subroutine pmc_mpi_transfer_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Transfer the value between the given processors.
  subroutine pmc_mpi_transfer_integer(from_val, to_val, from_proc, to_proc)

    !> Value to send.
    integer, intent(in) :: from_val
    !> Variable to send to.
    integer, intent(out) :: to_val
    !> Processor to send from.
    integer, intent(in) :: from_proc
    !> Processor to send to.
    integer, intent(in) :: to_proc

#ifdef PMC_USE_MPI
    integer :: rank, ierr, status(MPI_STATUS_SIZE)
    
    rank = pmc_mpi_rank()
    if (from_proc == to_proc) then
       if (rank == from_proc) then
          to_val = from_val
       end if
    else
       if (rank == from_proc) then
          call mpi_send(from_val, 1, MPI_INTEGER, to_proc, &
               208020430, MPI_COMM_WORLD, ierr)
          call pmc_mpi_check_ierr(ierr)
       elseif (rank == to_proc) then
          call mpi_recv(to_val, 1, MPI_INTEGER, from_proc, &
               208020430, MPI_COMM_WORLD, status, ierr)
          call pmc_mpi_check_ierr(ierr)
       end if
    end if
#else
    to_val = from_val
#endif

  end subroutine pmc_mpi_transfer_integer

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Computes the sum of \c val across all processes, storing the
  !> result in \c val_sum on the root process.
  subroutine pmc_mpi_reduce_sum_integer(val, val_sum)

    !> Value to sum.
    integer, intent(in) :: val
    !> Result.
    integer, intent(out) :: val_sum

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_reduce(val, val_sum, 1, MPI_INTEGER, MPI_SUM, 0, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
#else
    val_sum = val
#endif

  end subroutine pmc_mpi_reduce_sum_integer

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Computes the sum of \c val across all processes, storing the
  !> result in \c val_sum on all processes.
  subroutine pmc_mpi_allreduce_sum_integer(val, val_sum)

    !> Value to sum.
    integer, intent(in) :: val
    !> Result.
    integer, intent(out) :: val_sum

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_allreduce(val, val_sum, 1, MPI_INTEGER, MPI_SUM, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
#else
    val_sum = val
#endif

  end subroutine pmc_mpi_allreduce_sum_integer

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Computes the average of val across all processes, storing the
  !> result in val_avg on the root process.
  subroutine pmc_mpi_reduce_avg_real_array(val, val_avg)

    !> Value to average.
    real(kind=dp), intent(in) :: val(:)
    !> Result.
    real(kind=dp), intent(out) :: val_avg(:)

#ifdef PMC_USE_MPI
    integer :: ierr

    call assert(915136121, size(val) == size(val_avg))
    call mpi_reduce(val, val_avg, size(val), MPI_DOUBLE_PRECISION, &
         MPI_SUM, 0, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    if (pmc_mpi_rank() == 0) then
       val_avg = val_avg / real(pmc_mpi_size(), kind=dp)
    end if
#else
    val_avg = val
#endif

  end subroutine pmc_mpi_reduce_avg_real_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Computes the average of val across all processes, storing the
  !> result in val_avg on the root process.
  subroutine pmc_mpi_reduce_avg_real_array_2d(val, val_avg)

    !> Value to average.
    real(kind=dp), intent(in) :: val(:,:)
    !> Result.
    real(kind=dp), intent(out) :: val_avg(:,:)

#ifdef PMC_USE_MPI
    integer :: ierr

    call assert(131229046, size(val,1) == size(val_avg,1))
    call assert(992122167, size(val,2) == size(val_avg,2))
    call mpi_reduce(val, val_avg, size(val), MPI_DOUBLE_PRECISION, &
         MPI_SUM, 0, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    if (pmc_mpi_rank() == 0) then
       val_avg = val_avg / real(pmc_mpi_size(), kind=dp)
    end if
#else
    val_avg = val
#endif

  end subroutine pmc_mpi_reduce_avg_real_array_2d

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Computes the average of val across all processes, storing the
  !> result in val_avg on all processes.
  subroutine pmc_mpi_allreduce_average_real(val, val_avg)

    !> Value to average.
    real(kind=dp), intent(in) :: val
    !> Result.
    real(kind=dp), intent(out) :: val_avg

#ifdef PMC_USE_MPI
    integer :: ierr

    call mpi_allreduce(val, val_avg, 1, MPI_DOUBLE_PRECISION, MPI_SUM, &
         MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    val_avg = val_avg / real(pmc_mpi_size(), kind=dp)
#else
    val_avg = val
#endif

  end subroutine pmc_mpi_allreduce_average_real

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Computes the average of val across all processes, storing the
  !> result in val_avg on all processes.
  subroutine pmc_mpi_allreduce_average_real_array(val, val_avg)

    !> Value to average.
    real(kind=dp), intent(in) :: val(:)
    !> Result.
    real(kind=dp), intent(out) :: val_avg(:)

#ifdef PMC_USE_MPI
    integer :: ierr

    call assert(948533359, size(val) == size(val_avg))
    call mpi_allreduce(val, val_avg, size(val), MPI_DOUBLE_PRECISION, &
         MPI_SUM, MPI_COMM_WORLD, ierr)
    call pmc_mpi_check_ierr(ierr)
    val_avg = val_avg / real(pmc_mpi_size(), kind=dp)
#else
    val_avg = val
#endif

  end subroutine pmc_mpi_allreduce_average_real_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module pmc_mpi
