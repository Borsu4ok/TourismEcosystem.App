using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TourismEcosystem.App.Domain;
using TourismEcosystem.App.UnitOfWork;

namespace TourismEcosystem.App.Services;

public sealed class TourismBookingService
{
    private readonly string _connectionString;

    public TourismBookingService(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<BookingDetailsDto> BookAndPayAtomicallyAsync(
        long actorUserId,
        long touristUserId,
        long departureId,
        short participantsCount,
        string? promoCode,
        long? excursionId,
        string paymentMethod,
        string externalTxRef,
        decimal? overridePaymentAmount = null,
        CancellationToken ct = default)
    {
        await using var uow = await PostgresUnitOfWork.CreateAsync(_connectionString, ct);
        await uow.BeginTransactionAsync(ct);

        try
        {
            var bookingResult = await uow.Bookings.CreateBookingAsync(
                actorUserId,
                touristUserId,
                departureId,
                participantsCount,
                promoCode,
                excursionId,
                ct);

            var amountToPay = overridePaymentAmount ?? bookingResult.TotalAmount;

            await uow.Payments.RegisterPaymentAsync(
                actorUserId,
                bookingResult.BookingId,
                amountToPay,
                paymentMethod,
                externalTxRef,
                ct);

            var details = await uow.Bookings.GetBookingByIdAsync(bookingResult.BookingId, ct)
                ?? throw new InvalidOperationException("Failed to load booking details after creation.");

            await uow.CommitAsync(ct);
            return details;
        }
        catch
        {
            await uow.RollbackAsync(ct);
            throw;
        }
    }
}