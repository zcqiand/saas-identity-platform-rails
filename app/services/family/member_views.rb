# frozen_string_literal: true

# 会员视图装配（springboot MemberViewAssembler 镜像）。
# roleIds 三处同源（members 视图 / login.availableTenants / me）：member_role join 原样，
# 不按 sys_role.tenant_id 过滤 —— 赋权端点负责只收本租户 role。
module Family
  module MemberViews
    module_function

    def role_ids(member_id)
      TenantMemberRole.where(member_id: member_id).order(:role_id).pluck(:role_id)
    end

    # TenantMembership：login.availableTenants / me.tenants / me.memberships 通用项
    def membership(member)
      {
        id: member.id,
        user_id: member.user_id,
        tenant_id: member.tenant_id,
        role_ids: role_ids(member.id),
        status: Dicts.member_status(member.status),
        joined_at: member.created_at
      }
    end

    # 全量 memberships（whoami 用，含非 active）
    def memberships_for(user_id)
      TenantMember.where(user_id: user_id).order(:created_at).map { |m| membership(m) }
    end

    # 扁平成员视图（TenantMemberUserView）：path {userId} = sys_user.id，视图 status 读 member 行
    def flat_user_view(member, user)
      {
        id: user.id,
        tenant_id: member.tenant_id,
        username: user.username,
        email: user.email,
        status: Dicts.member_status(member.status),
        role_ids: role_ids(member.id),
        created_at: member.created_at,
        updated_at: member.updated_at
      }
    end

    # 嵌套视图（invitations）：{ member, user, roles }
    def nested_view(member, user)
      {
        member: member_part(member),
        user: user_part(user),
        roles: []
      }
    end

    def member_part(member)
      {
        id: member.id,
        tenant_id: member.tenant_id,
        user_id: member.user_id,
        member_name: member.member_name,
        is_owner: member.is_owner,
        status: Dicts.member_status(member.status),
        created_at: member.created_at,
        updated_at: member.updated_at
      }
    end

    def user_part(user)
      {
        id: user.id,
        username: user.username,
        email: user.email,
        mobile: user.mobile,
        status: Dicts.user_status(user.status),
        failed_attempts: user.failed_attempts,
        locked_until: user.locked_until,
        created_at: user.created_at,
        updated_at: user.updated_at
      }
    end
  end
end
