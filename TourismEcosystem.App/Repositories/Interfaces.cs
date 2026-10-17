using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TourismEcosystem.App.Domain;

namespace TourismEcosystem.App.Repositories;

public interface ITourRepository
{
    Task<IReadOnlyList<TourOfferDto>> SearchActiveToursAsync(
        string? countryIso = null,
        DateOnly? minDate = null,
        decimal? maxPrice = null,
        string? tag = null,
        CancellationToken ct = default);

    Task SoftDeleteTourAsync(long actorUserId, long tourId, CancellationToken ct = default);
    Task RestoreRecordAsync(long actorUserId, string entityName, long recordId, CancellationToken ct = default);
    Task<IReadOnlyList<DeletedRecordDto>> GetDeletedRecordsAsync(CancellationToken ct = default);
}

public interface IBookingRepository
{
    Task<BookingCreationResult> CreateBookingAsync(
        long actorUserId,
        long touristUserId,
        long departureId,
        short participantsCount,
        string? promoCode,
        long? excursionId,
        CancellationToken ct = default);

    Task<BookingDetailsDto?> GetBookingByIdAsync(long bookingId, CancellationToken ct = default);
    Task<IReadOnlyList<BookingDetailsDto>> GetBookingsByUserAsync(long userId, CancellationToken ct = default);
}

public interface IPaymentRepository
{
    Task<PaymentRegistrationResult> RegisterPaymentAsync(
        long actorUserId,
        long bookingId,
        decimal amount,
        string paymentMethod,
        string externalTxRef,
        CancellationToken ct = default);
}