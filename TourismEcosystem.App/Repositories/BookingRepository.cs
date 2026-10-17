using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using TourismEcosystem.App.Domain;

namespace TourismEcosystem.App.Repositories;

public sealed class BookingRepository : IBookingRepository
{
    private readonly NpgsqlConnection _connection;
    private readonly Func<NpgsqlTransaction?> _transactionProvider;

    public BookingRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transactionProvider)
    {
        _connection = connection;
        _transactionProvider = transactionProvider;
    }

    public async Task<BookingCreationResult> CreateBookingAsync(
        long actorUserId,
        long touristUserId,
        long departureId,
        short participantsCount,
        string? promoCode,
        long? excursionId,
        CancellationToken ct = default)
    {
        const string sql = @"
            CALL tourism.sp_create_booking(
                @p_actor_user_id, @p_tourist_user_id, @p_departure_id,
                @p_participants_count, @p_promo_code, @p_excursion_id,
                @o_booking_id, @o_booking_number, @o_total_amount
            );";

        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        cmd.Parameters.AddWithValue("p_actor_user_id", NpgsqlDbType.Bigint, actorUserId);
        cmd.Parameters.AddWithValue("p_tourist_user_id", NpgsqlDbType.Bigint, touristUserId);
        cmd.Parameters.AddWithValue("p_departure_id", NpgsqlDbType.Bigint, departureId);
        cmd.Parameters.AddWithValue("p_participants_count", NpgsqlDbType.Smallint, participantsCount);
        cmd.Parameters.Add(new NpgsqlParameter("p_promo_code", NpgsqlDbType.Varchar) { Value = (object?)promoCode ?? DBNull.Value });
        cmd.Parameters.Add(new NpgsqlParameter("p_excursion_id", NpgsqlDbType.Bigint) { Value = excursionId.HasValue ? excursionId.Value : DBNull.Value });

        var outId = new NpgsqlParameter("o_booking_id", NpgsqlDbType.Bigint)
        {
            Direction = ParameterDirection.InputOutput,
            Value = DBNull.Value
        };
        var outNumber = new NpgsqlParameter("o_booking_number", NpgsqlDbType.Varchar, 40)
        {
            Direction = ParameterDirection.InputOutput,
            Value = DBNull.Value
        };
        var outTotal = new NpgsqlParameter("o_total_amount", NpgsqlDbType.Numeric)
        {
            Direction = ParameterDirection.InputOutput,
            Value = DBNull.Value
        };

        cmd.Parameters.Add(outId);
        cmd.Parameters.Add(outNumber);
        cmd.Parameters.Add(outTotal);

        await cmd.ExecuteNonQueryAsync(ct);

        return new BookingCreationResult(
            Convert.ToInt64(outId.Value),
            Convert.ToString(outNumber.Value) ?? string.Empty,
            Convert.ToDecimal(outTotal.Value)
        );
    }

    public async Task<BookingDetailsDto?> GetBookingByIdAsync(long bookingId, CancellationToken ct = default)
    {
        const string sql = @"
            SELECT booking_id, booking_number, user_id, tourist_name, tourist_email,
                   tour_title, start_date, end_date, participants_count,
                   total_amount, paid_amount, booking_status
            FROM tourism.vw_booking_details
            WHERE booking_id = @p_booking_id;";

        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        cmd.Parameters.AddWithValue("p_booking_id", NpgsqlDbType.Bigint, bookingId);

        await using var reader = await cmd.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct))
        {
            return null;
        }

        return MapBookingDetails(reader);
    }

    public async Task<IReadOnlyList<BookingDetailsDto>> GetBookingsByUserAsync(long userId, CancellationToken ct = default)
    {
        const string sql = @"
            SELECT booking_id, booking_number, user_id, tourist_name, tourist_email,
                   tour_title, start_date, end_date, participants_count,
                   total_amount, paid_amount, booking_status
            FROM tourism.vw_booking_details
            WHERE user_id = @p_user_id
            ORDER BY booking_id DESC;";

        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        cmd.Parameters.AddWithValue("p_user_id", NpgsqlDbType.Bigint, userId);

        var list = new List<BookingDetailsDto>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            list.Add(MapBookingDetails(reader));
        }
        return list;
    }

    private static BookingDetailsDto MapBookingDetails(NpgsqlDataReader reader)
    {
        return new BookingDetailsDto(
            reader.GetInt64(0),
            reader.GetString(1),
            reader.GetInt64(2),
            reader.GetString(3),
            reader.GetString(4),
            reader.GetString(5),
            reader.GetFieldValue<DateOnly>(6),
            reader.GetFieldValue<DateOnly>(7),
            reader.GetInt16(8),
            reader.GetDecimal(9),
            reader.GetDecimal(10),
            reader.GetString(11)
        );
    }
}