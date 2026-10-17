using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TourismEcosystem.App.Domain;

public sealed record TourOfferDto(
    long TourId,
    string TourCode,
    string TourTitle,
    long DepartureId,
    DateOnly StartDate,
    DateOnly EndDate,
    decimal EffectivePrice,
    short AvailableSeats,
    string[] Tags
);

public sealed record BookingDetailsDto(
    long BookingId,
    string BookingNumber,
    long UserId,
    string TouristName,
    string TouristEmail,
    string TourTitle,
    DateOnly StartDate,
    DateOnly EndDate,
    short ParticipantsCount,
    decimal TotalAmount,
    decimal PaidAmount,
    string BookingStatus
);

public sealed record BookingCreationResult(
    long BookingId,
    string BookingNumber,
    decimal TotalAmount
);

public sealed record PaymentRegistrationResult(
    long PaymentId,
    string UpdatedBookingStatus
);

public sealed record DeletedRecordDto(
    string EntityType,
    long RecordId,
    string Identifier,
    DateTime DeletedAt,
    long? DeletedByUserId
);
