! Copyright (C) 2007-2011 Matthew West
! Licensed under the GNU General Public License version 2 or (at your
! option) any later version. See the file COPYING for details.

!> \file
!> The pmc_rand module.

!> Random number generators.
module pmc_rand
  
  use pmc_util
  use pmc_constants
  use pmc_mpi
#ifdef PMC_USE_GSL
  use iso_c_binding
#endif

  !> Length of a UUID string.
  integer, parameter :: PMC_UUID_LEN = 36

#ifdef PMC_USE_GSL
  integer, parameter :: PMC_RAND_GSL_SUCCESS      = 0
  integer, parameter :: PMC_RAND_GSL_INIT_FAIL    = 1
  integer, parameter :: PMC_RAND_GSL_NOT_INIT     = 2
  integer, parameter :: PMC_RAND_GSL_ALREADY_INIT = 3
#endif
  
contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#ifdef PMC_USE_GSL
  !> Check the return value of a call to one of the GSL RNG functions.
  subroutine rand_check_gsl(code, value)

    !> Error code.
    integer :: code
    !> Return value.
    integer(kind=c_int) :: value

    if (value == PMC_RAND_GSL_SUCCESS) then
       return
    elseif (value == PMC_RAND_GSL_INIT_FAIL) then
       call die_msg(code, "GSL RNG initialization failed")
    elseif (value == PMC_RAND_GSL_NOT_INIT) then
       call die_msg(code, "GSL RNG has not been successfully initialized")
    elseif (value == PMC_RAND_GSL_ALREADY_INIT) then
       call die_msg(code, "GSL RNG was already initialized")
    else
       call die_msg(code, "Unknown GSL RNG interface return value: " &
            // trim(integer_to_string(value)))
    end if

  end subroutine rand_check_gsl
#endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Initializes the random number generator to the state defined by
  !> the given seed plus offset. If the seed is 0 then a seed is
  !> auto-generated from the current time plus offset.
  subroutine pmc_srand(seed, offset)

    !> Random number generator seed.
    integer, intent(in) :: seed
    !> Random number generator offset.
    integer, intent(in) :: offset

    integer :: i, n, clock
    integer, allocatable :: seed_vec(:)
#ifdef PMC_USE_GSL
    integer(kind=c_int) :: c_clock
#endif
    ! FIXME: HACK
    real(kind=dp) :: r
    ! FIXME: end HACK

#ifdef PMC_USE_GSL
#ifndef DOXYGEN_SKIP_DOC
    interface
       integer(kind=c_int) function pmc_srand_gsl(seed) bind(c)
         use iso_c_binding
         integer(kind=c_int), value :: seed
       end function pmc_srand_gsl
    end interface
#endif
#endif

    if (seed == 0) then
       if (pmc_mpi_rank() == 0) then
          call system_clock(count = clock)
       end if
       ! ensure all nodes use exactly the same seed base, to avoid
       ! accidental correlations
       call pmc_mpi_bcast_integer(clock)
    else
       clock = seed
    end if
    clock = clock + 67 * offset
#ifdef PMC_USE_GSL
    c_clock = int(clock, kind=c_int)
    call rand_check_gsl(100489590, pmc_srand_gsl(c_clock))
#else
    call random_seed(size = n)
    allocate(seed_vec(n))
    i = 0 ! HACK to shut up gfortran warning
    seed_vec = clock + 37 * (/ (i - 1, i = 1, n) /)
    call random_seed(put = seed_vec)
    deallocate(seed_vec)
    ! FIXME: HACK for bad rng behavior from pgf90
    do i = 1,1000
       r = pmc_random()
    end do
    ! FIXME: end HACK
#endif

  end subroutine pmc_srand

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Cleanup the random number generator.
  subroutine pmc_rand_finalize()

#ifdef PMC_USE_GSL

#ifndef DOXYGEN_SKIP_DOC
    interface
       integer(kind=c_int) function pmc_rand_finalize_gsl() bind(c)
         use iso_c_binding
       end function pmc_rand_finalize_gsl
    end interface
#endif

    call rand_check_gsl(489538382, pmc_rand_finalize_gsl())
#endif

  end subroutine pmc_rand_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns a random number between 0 and 1.
  real(kind=dp) function pmc_random()

#ifdef PMC_USE_GSL
    real(kind=c_double), target :: rnd
    type(c_ptr) :: rnd_ptr
#else
    real(kind=dp) :: rnd
#endif

#ifdef PMC_USE_GSL
#ifndef DOXYGEN_SKIP_DOC
    interface
       integer(kind=c_int) function pmc_rand_gsl(harvest) bind(c)
         use iso_c_binding
         type(c_ptr), value :: harvest
       end function pmc_rand_gsl
    end interface
#endif
#endif

#ifdef PMC_USE_GSL
    rnd_ptr = c_loc(rnd)
    call rand_check_gsl(843777138, pmc_rand_gsl(rnd_ptr))
    pmc_random = real(rnd, kind=dp)
#else
    call random_number(rnd)
    pmc_random = rnd
#endif

  end function pmc_random
  
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns a random integer between 1 and n.
  integer function pmc_rand_int(n)

    !> Maximum random number to generate.
    integer, intent(in) :: n

#ifdef PMC_USE_GSL
    integer(kind=c_int) :: n_c
    integer(kind=c_int), target :: harvest
    type(c_ptr) :: harvest_ptr
#endif

#ifdef PMC_USE_GSL
#ifndef DOXYGEN_SKIP_DOC
    interface
       integer(kind=c_int) function pmc_rand_int_gsl(n, harvest) bind(c)
         use iso_c_binding
         integer(kind=c_int), value :: n
         type(c_ptr), value :: harvest
       end function pmc_rand_int_gsl
    end interface
#endif
#endif

#ifdef PMC_USE_GSL
    n_c = int(n, kind=c_int)
    harvest_ptr = c_loc(harvest)
    call rand_check_gsl(388234845, pmc_rand_int_gsl(n_c, harvest_ptr))
    pmc_rand_int = int(harvest)
#else
    pmc_rand_int = mod(int(pmc_random() * real(n, kind=dp)), n) + 1
#endif
    call assert(515838689, pmc_rand_int >= 1)
    call assert(802560153, pmc_rand_int <= n)

  end function pmc_rand_int

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Round val to \c floor(val) or \c ceiling(val) with probability
  !> proportional to the relative distance from \c val. That is,
  !> Prob(prob_round(val) == floor(val)) = ceil(val) - val.
  integer function prob_round(val)

    !> Value to round.
    real(kind=dp), intent(in) :: val
    
    if (pmc_random() < real(ceiling(val), kind=dp) - val) then
       prob_round = floor(val)
    else
       prob_round = ceiling(val)
    endif

  end function prob_round

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Generate a Poisson-distributed random number with the given
  !> mean.
  !!
  !! See http://en.wikipedia.org/wiki/Poisson_distribution for
  !! information on the method. The method used at present is rather
  !! inefficient and inaccurate (brute force for mean below 10 and
  !! normal approximation above that point).
  !!
  !! The best known method appears to be due to Ahrens and Dieter (ACM
  !! Trans. Math. Software, 8(2), 163-179, 1982) and is available (in
  !! various forms) from:
  !!     - http://www.netlib.org/toms/599
  !!     - http://www.netlib.org/random/ranlib.f.tar.gz
  !!     - http://users.bigpond.net.au/amiller/random/random.f90
  !!     - http://www.netlib.org/random/random.f90
  !!
  !! Unfortunately the above code is under the non-free license:
  !!     - http://www.acm.org/pubs/copyright_policy/softwareCRnotice.html
  integer function rand_poisson(mean)

    !> Mean of the distribution.
    real(kind=dp), intent(in) :: mean

#ifdef PMC_USE_GSL
    real(kind=c_double) :: mean_c
    integer(kind=c_int), target :: harvest
    type(c_ptr) :: harvest_ptr
#else
    real(kind=dp) :: L, p
    integer :: k
#endif

#ifdef PMC_USE_GSL
#ifndef DOXYGEN_SKIP_DOC
    interface
       integer(kind=c_int) function pmc_rand_poisson_gsl(mean, harvest) &
            bind(c)
         use iso_c_binding
         real(kind=c_double), value :: mean
         type(c_ptr), value :: harvest
       end function pmc_rand_poisson_gsl
    end interface
#endif
#endif

#ifdef PMC_USE_GSL
    mean_c = real(mean, kind=c_double)
    harvest_ptr = c_loc(harvest)
    call rand_check_gsl(208869397, &
         pmc_rand_poisson_gsl(mean_c, harvest_ptr))
    rand_poisson = int(harvest)
#else
    if (mean <= 10d0) then
       ! exact method due to Knuth
       L = exp(-mean)
       k = 0
       p = 1d0
       do
          k = k + 1
          p = p * pmc_random()
          if (p < L) exit
       end do
       rand_poisson = k - 1
    else
       ! normal approximation with a continuity correction
       k = nint(rand_normal(mean - 0.5d0, sqrt(mean)))
       rand_poisson = max(k, 0)
    end if
#endif

  end function rand_poisson

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Generates a normally distributed random number with the given
  !> mean and standard deviation.
  real(kind=dp) function rand_normal(mean, stddev)

    !> Mean of distribution.
    real(kind=dp), intent(in) :: mean
    !> Standard deviation of distribution.
    real(kind=dp), intent(in) :: stddev

    real(kind=dp) :: u1, u2, r, theta, z0, z1

    ! Uses the Box-Muller transform
    ! http://en.wikipedia.org/wiki/Box-Muller_transform
    u1 = pmc_random()
    u2 = pmc_random()
    r = sqrt(-2d0 * log(u1))
    theta = 2d0 * const%pi * u2
    z0 = r * cos(theta)
    z1 = r * sin(theta)
    ! z0 and z1 are now independent N(0,1) random variables
    ! We through away z1, but we could use a SAVE variable to only do
    ! the computation on every second call of this function.
    rand_normal = stddev * z0 + mean

  end function rand_normal

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sample the given continuous probability density function.
  !!
  !! That is, return a number k = 1,...,n such that prob(k) = pdf(k) /
  !! sum(pdf).
  integer function sample_cts_pdf(pdf)

    !> Probability density function (not normalized).
    real(kind=dp), intent(in) :: pdf(:)

    real(kind=dp) :: pdf_max
    integer :: k
    logical :: found

    ! use accept-reject
    pdf_max = maxval(pdf)
    if (minval(pdf) < 0d0) then
       call die_msg(121838078, 'pdf contains negative values')
    end if
    if (pdf_max <= 0d0) then
       call die_msg(119208863, 'pdf is not positive')
    end if
    found = .false.
    do while (.not. found)
       k = pmc_rand_int(size(pdf))
       if (pmc_random() < pdf(k) / pdf_max) then
          found = .true.
       end if
    end do
    sample_cts_pdf = k

  end function sample_cts_pdf

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sample the given discrete probability density function.
  !!
  !! That is, return a number k = 1,...,n such that prob(k) = pdf(k) /
  !! sum(pdf).
  integer function sample_disc_pdf(pdf)

    !> Probability density function.
    integer, intent(in) :: pdf(:)

    integer :: pdf_max, k
    logical :: found

    ! use accept-reject
    pdf_max = maxval(pdf)
    if (minval(pdf) < 0) then
       call die_msg(598024763, 'pdf contains negative values')
    end if
    if (pdf_max <= 0) then
       call die_msg(109961454, 'pdf is not positive')
    end if
    found = .false.
    do while (.not. found)
       k = pmc_rand_int(size(pdf))
       if (pmc_random() < real(pdf(k), kind=dp) / real(pdf_max, kind=dp)) then
          found = .true.
       end if
    end do
    sample_disc_pdf = k

  end function sample_disc_pdf
  
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Convert a real-valued vector into an integer-valued vector by
  !> sampling.
  !!
  !! Use n_samp samples. Each discrete entry is sampled with a PDF
  !! given by vec_cts. This is very slow for large n_samp or large n.
  subroutine sample_vec_cts_to_disc(vec_cts, n_samp, vec_disc)
    
    !> Continuous vector.
    real(kind=dp), intent(in) :: vec_cts(:)
    !> Number of discrete samples to use.
    integer, intent(in) :: n_samp
    !> Discretized vector.
    integer, intent(out) :: vec_disc(size(vec_cts))

    integer :: i_samp, k

    vec_disc = 0
    do i_samp = 1,n_samp
       k = sample_cts_pdf(vec_cts)
       vec_disc(k) = vec_disc(k) + 1
    end do
    
  end subroutine sample_vec_cts_to_disc
  
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Generate a random hexadecimal character.
  character function rand_hex_char()

    integer :: i

    i = pmc_rand_int(16)
    if (i <= 10) then
       rand_hex_char = achar(iachar('0') + i - 1)
    else
       rand_hex_char = achar(iachar('A') + i - 11)
    end if

  end function rand_hex_char

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Generate a version 4 UUID as a string.
  !!
  !! See http://en.wikipedia.org/wiki/Universally_Unique_Identifier
  !! for format details.
  subroutine uuid4_str(uuid)

    character(len=PMC_UUID_LEN), intent(out) :: uuid

    integer :: i

    do i = 1,8
       uuid(i:i) = rand_hex_char()
    end do
    uuid(9:9) = '-'
    do i = 1,4
       uuid((i + 9):(i + 9)) = rand_hex_char()
    end do
    uuid(14:14) = '-'
    do i = 1,4
       uuid((i + 14):(i + 14)) = rand_hex_char()
    end do
    uuid(19:19) = '-'
    do i = 1,4
       uuid((i + 19):(i + 19)) = rand_hex_char()
    end do
    uuid(24:24) = '-'
    do i = 1,12
       uuid((i + 24):(i + 24)) = rand_hex_char()
    end do

    uuid(15:15) = '4'

    i = pmc_rand_int(4)
    if (i <= 2) then
       uuid(20:20) = achar(iachar('8') + i - 1)
    else
       uuid(20:20) = achar(iachar('A') + i - 3)
    end if

  end subroutine uuid4_str

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module pmc_rand
