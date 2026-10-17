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

public sealed class TourRepository : ITourRepository
{
    private readonly NpgsqlConnection _connection;
    private readonly Func<NpgsqlTransaction?> _transactionProvider;

    public TourRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transactionProvider)
    {
        _connection = connection;
        _transactionProvider = transactionProvider;
    }

    public async Task<IReadOnlyList<TourOfferDto>> SearchActiveToursAsync(
        string? countryIso = null,
        DateOnly? minDate = null,
        decimal? maxPrice = null,
        string? tag = null,
        CancellationToken ct = default)
    {
        const string sql = @"
            SELECT tour_id, tour_code, tour_title, departure_id, start_date, end_date,
                   effective_price, available_seats, tags
            FROM tourism.fn_search_tours(@p_country_iso, @p_min_date, @p_max_price, @p_tag);";

        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        cmd.Parameters.Add(new NpgsqlParameter("p_country_iso", NpgsqlDbType.Char) { Value = (object?)countryIso ?? DBNull.Value });
        cmd.Parameters.Add(new NpgsqlParameter("p_min_date", NpgsqlDbType.Date) { Value = minDate.HasValue ? minDate.Value : DBNull.Value });
        cmd.Parameters.Add(new NpgsqlParameter("p_max_price", NpgsqlDbType.Numeric) { Value = maxPrice.HasValue ? maxPrice.Value : DBNull.Value });
        cmd.Parameters.Add(new NpgsqlParameter("p_tag", NpgsqlDbType.Text) { Value = (object?)tag ?? DBNull.Value });

        var results = new List<TourOfferDto>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            results.Add(new TourOfferDto(
                reader.GetInt64(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetInt64(3),
                reader.GetFieldValue<DateOnly>(4),
                reader.GetFieldValue<DateOnly>(5),
                reader.GetDecimal(6),
                reader.GetInt16(7),
                reader.GetFieldValue<string[]>(8)
            ));
        }
        return results;
    }

    public async Task SoftDeleteTourAsync(long actorUserId, long tourId, CancellationToken ct = default)
    {
        const string sql = "CALL tourism.sp_soft_delete_tour(@p_actor_user_id, @p_tour_id);";
        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        cmd.Parameters.AddWithValue("p_actor_user_id", NpgsqlDbType.Bigint, actorUserId);
        cmd.Parameters.AddWithValue("p_tour_id", NpgsqlDbType.Bigint, tourId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task RestoreRecordAsync(long actorUserId, string entityName, long recordId, CancellationToken ct = default)
    {
        const string sql = "CALL tourism.sp_restore_soft_deleted_record(@p_actor_user_id, @p_entity_name, @p_record_id);";
        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        cmd.Parameters.AddWithValue("p_actor_user_id", NpgsqlDbType.Bigint, actorUserId);
        cmd.Parameters.AddWithValue("p_entity_name", NpgsqlDbType.Varchar, entityName);
        cmd.Parameters.AddWithValue("p_record_id", NpgsqlDbType.Bigint, recordId);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task<IReadOnlyList<DeletedRecordDto>> GetDeletedRecordsAsync(CancellationToken ct = default)
    {
        const string sql = @"
            SELECT entity_type, record_id, identifier, deleted_at, deleted_by_user_id
            FROM tourism.vw_deleted_records_registry
            ORDER BY deleted_at DESC;";

        await using var cmd = new NpgsqlCommand(sql, _connection, _transactionProvider());
        var list = new List<DeletedRecordDto>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            list.Add(new DeletedRecordDto(
                reader.GetString(0),
                reader.GetInt64(1),
                reader.GetString(2),
                reader.GetDateTime(3),
                reader.IsDBNull(4) ? null : reader.GetInt64(4)
            ));
        }
        return list;
    }
}